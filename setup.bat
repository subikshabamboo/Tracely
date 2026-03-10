@echo off
REM Tracely Setup Script for Windows
REM This script sets up and runs the Tracely application

echo ========================================
echo       Tracely Setup Script
echo ========================================
echo.

REM Check if Docker is running
echo [1/6] Checking Docker status...
docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: Docker is not running. Please start Docker Desktop and try again.
    exit /b 1
)
echo Docker is running.
echo.

REM Check if .env exists, create if not
echo [2/6] Setting up environment variables...
if not exist ".env" (
    echo Creating .env file with default settings...
    (
        echo DATABASE_URL=postgres://tracely_user:tracely_password@localhost:5432/tracely?sslmode=disable
        echo JWT_SECRET=your-super-secret-jwt-key-change-in-production
        echo PORT=8080
        echo ALLOWED_ORIGIN=http://localhost:3000
    ) > .env
    echo .env file created with default values.
    echo IMPORTANT: Please update JWT_SECRET in .env for production!
) else (
    echo .env file already exists.
)
echo.

REM Start Docker services
echo [3/6] Starting Docker services (PostgreSQL, Redis, Prometheus, Toxiproxy)...
docker-compose up -d
if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to start Docker services.
    exit /b 1
)
echo Docker services started.
echo.

REM Wait for PostgreSQL to be ready
echo [4/6] Waiting for PostgreSQL to be ready...
:wait_for_db
docker exec tracely-db pg_isready -U tracely_user >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Waiting for database...
    timeout /t 2 /nobreak >nul
    goto wait_for_db
)
echo PostgreSQL is ready.
echo.

REM Build and run the backend
echo [5/6] Building backend...
cd backend
go build -o server.exe cmd/server/main.go
if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to build backend.
    exit /b 1
)
echo Backend built successfully.
echo.

REM Start the backend server
echo [6/6] Starting backend server...
start "Tracely Backend" cmd /k "set DATABASE_URL=postgres://tracely_user:tracely_password@localhost:5432/tracely?sslmode=disable && set JWT_SECRET=your-super-secret-jwt-key-change-in-production && set PORT=8080 && set ALLOWED_ORIGIN=http://localhost:3000 && server.exe"

echo.
echo ========================================
echo       Setup Complete!
echo ========================================
echo.
echo Services running:
echo   - PostgreSQL:  localhost:5432
echo   - Redis:       localhost:6379
echo   - Prometheus:  localhost:9090
echo   - Toxiproxy:   localhost:8474, localhost:8666
echo   - Backend:     localhost:8080
echo.
echo To run the frontend:
echo   cd frontend
echo   flutter run -d chrome
echo.
echo OR for web build:
echo   cd frontend
echo   flutter build web
echo   Then serve the web/build folder
echo.
echo Press any key to exit...
pause >nul

