#!/bin/bash
# Tracely Setup Script for Linux/Mac
# This script sets up and runs the Tracely application

echo "========================================"
echo "      Tracely Setup Script"
echo "========================================"
echo ""

# Check if Docker is running
echo "[1/6] Checking Docker status..."
if ! docker info > /dev/null 2>&1; then
    echo "ERROR: Docker is not running. Please start Docker and try again."
    exit 1
fi
echo "Docker is running."
echo ""

# Check if .env exists, create if not
echo "[2/6] Setting up environment variables..."
if [ ! -f ".env" ]; then
    echo "Creating .env file with default settings..."
    cat > .env << 'EOF'
DATABASE_URL=postgres://tracely_user:tracely_password@localhost:5432/tracely?sslmode=disable
JWT_SECRET=your-super-secret-jwt-key-change-in-production
PORT=8080
ALLOWED_ORIGIN=http://localhost:3000
EOF
    echo ".env file created with default values."
    echo "IMPORTANT: Please update JWT_SECRET in .env for production!"
else
    echo ".env file already exists."
fi
echo ""

# Start Docker services
echo "[3/6] Starting Docker services (PostgreSQL, Redis, Prometheus, Toxiproxy)..."
docker-compose up -d
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to start Docker services."
    exit 1
fi
echo "Docker services started."
echo ""

# Wait for PostgreSQL to be ready
echo "[4/6] Waiting for PostgreSQL to be ready..."
until docker exec tracely-db pg_isready -U tracely_user > /dev/null 2>&1; do
    echo "Waiting for database..."
    sleep 2
done
echo "PostgreSQL is ready."
echo ""

# Build the backend
echo "[5/6] Building backend..."
cd backend
go build -o server cmd/server/main.go
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to build backend."
    exit 1
fi
echo "Backend built successfully."
echo ""

# Export environment variables and start backend
echo "[6/6] Starting backend server..."
export DATABASE_URL="postgres://tracely_user:tracely_password@localhost:5432/tracely?sslmode=disable"
export JWT_SECRET="your-super-secret-jwt-key-change-in-production"
export PORT="8080"
export ALLOWED_ORIGIN="http://localhost:3000"

# Start backend in background
./server &
BACKEND_PID=$!

echo ""
echo "========================================"
echo "      Setup Complete!"
echo "========================================"
echo ""
echo "Services running:"
echo "  - PostgreSQL:  localhost:5432"
echo "  - Redis:       localhost:6379"
echo "  - Prometheus:  localhost:9090"
echo "  - Toxiproxy:   localhost:8474, localhost:8666"
echo "  - Backend:     localhost:8080"
echo ""
echo "Backend PID: $BACKEND_PID"
echo ""
echo "To run the frontend:"
echo "  cd frontend"
echo "  flutter run -d chrome"
echo ""
echo "Or for web build:"
echo "  cd frontend"
echo "  flutter build web"
echo "  Then serve the web/build folder"
echo ""

