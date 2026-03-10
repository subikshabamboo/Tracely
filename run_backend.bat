te_path>g:/Tracely/run_backend.bat</absolute_path>
<parameter name="content">@echo off
REM Tracely Backend Runner
REM Sets required environment variables and runs the backend server

echo Starting Tracely Backend...
echo.

REM Set required environment variables
set DATABASE_URL=postgres://tracely_user:tracely_password@localhost:5432/tracely?sslmode=disable
set JWT_SECRET=subi@2006
set ENCRYPTION_KEY=your-32-byte-encryption-key-here
set PORT=8080
set ALLOWED_ORIGIN=http://localhost:3000

echo Environment variables set:
echo   DATABASE_URL=%DATABASE_URL%
echo   JWT_SECRET=*** (hidden)
echo   ENCRYPTION_KEY=*** (hidden)
echo   PORT=%PORT%
echo   ALLOWED_ORIGIN=%ALLOWED_ORIGIN%
echo.

REM Run the backend
cd /d "%~dp0backend"
go run ./cmd/server
