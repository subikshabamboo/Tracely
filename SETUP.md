# Tracely Setup Guide

## Prerequisites

Ensure you have the following installed:
- **Docker Desktop** for Windows
- **Go** (1.21+)
- **Flutter** SDK (3.x)
- **Node.js** (optional, for additional tooling)

---

## Quick Start

### Option 1: Automated Setup (Recommended)

Run the setup script:
```bash
setup.bat
```

This will:
1. Check Docker is running
2. Create `.env` file with default values
3. Start all Docker services (PostgreSQL, Redis, Prometheus, Toxiproxy)
4. Build and start the backend server

### Option 2: Manual Setup

#### Step 1: Start Docker Services

```bash
docker-compose up -d
```

This starts:
| Service      | Port  | Description              |
|--------------|-------|--------------------------|
| PostgreSQL   | 5432  | Main database            |
| Redis        | 6379  | Caching & sessions       |
| Prometheus   | 9090  | Metrics collection       |
| Toxiproxy    | 8474  | Network chaos testing    |
| Toxiproxy UI | 8666  | Toxiproxy admin UI       |

#### Step 2: Configure Environment Variables

Create a `.env` file in the project root:

```env
# Database - matches docker-compose.yml
DATABASE_URL=postgres://tracely_user:tracely_password@localhost:5432/tracely?sslmode=disable

# JWT Authentication - CHANGE THIS IN PRODUCTION!
JWT_SECRET=your-super-secret-jwt-key-change-in-production

# Server
PORT=8080
ALLOWED_ORIGIN=http://localhost:3000
```

#### Step 3: Build and Run Backend

```bash
cd backend
go build -o server.exe cmd/server/main.go
set DATABASE_URL=postgres://tracely_user:tracely_password@localhost:5432/tracely?sslmode=disable
set JWT_SECRET=your-super-secret-jwt-key-change-in-production
set PORT=8080
set ALLOWED_ORIGIN=http://localhost:3000
server.exe
```

Or run directly with Go:
```bash
cd backend/cmd/server
set DATABASE_URL=postgres://tracely_user:tracely_password@localhost:5432/tracely?sslmode=disable
set JWT_SECRET=your-super-secret-jwt-key-change-in-production
go run main.go
```

#### Step 4: Run Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

For web build:
```bash
flutter build web
# Serve the web/build folder with any HTTP server
```

---

## Service URLs

| Service      | URL                                   |
|--------------|---------------------------------------|
| Backend API  | http://localhost:8080/api/v1         |
| Frontend     | http://localhost:3000                 |
| Prometheus   | http://localhost:9090                 |
| Toxiproxy    | http://localhost:8666                 |

---

## First Time Setup

### Create Initial User

After starting the backend, use the API to register:

```bash
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@tracely.io", "password": "admin123", "full_name": "Admin User"}'
```

Then login:
```bash
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@tracely.io", "password": "admin123"}'
```

### Create First Workspace

Using the obtained token:
```bash
curl -X POST http://localhost:8080/api/v1/workspaces \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{"name": "My Workspace"}'
```

---

## Troubleshooting

### PostgreSQL Connection Failed

Check if the container is running:
```bash
docker ps | grep tracely-db
```

Check logs:
```bash
docker logs tracely-db
```

### Port Already in Use

If port 8080 is in use, change the PORT in `.env`:
```env
PORT=8081
```

### JWT Secret Error

Ensure `JWT_SECRET` is set in environment variables before running the backend.

### CORS Errors

If frontend can't connect to backend, check `ALLOWED_ORIGIN` matches your frontend URL:
```env
ALLOWED_ORIGIN=http://localhost:3000
```

---

## Development Commands

```bash
# Restart Docker services
docker-compose restart

# View backend logs
docker logs tracely-db

# Rebuild backend
cd backend && go build -o server.exe cmd/server/main.go

# Reset database (WARNING: deletes all data)
docker-compose down -v
docker-compose up -d

# Run tests
cd backend && go test ./...
cd frontend && flutter test
```

---

## Production Considerations

1. **Change JWT_SECRET** to a secure random string
2. **Enable SSL** for PostgreSQL (update DATABASE_URL)
3. **Secure Redis** with password
4. **Configure proper CORS** for production domains
5. **Set up logging** (e.g., to file or cloud service)
6. **Use environment-specific configs** (dev/staging/prod)

