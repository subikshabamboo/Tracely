# Tracely Local Setup (Without Docker)

## Prerequisites

Install the following on your Windows machine:
1. **PostgreSQL** (15.x recommended) - https://www.postgresql.org/download/windows/
2. **Go** (1.21+) - https://go.dev/dl/
3. **Flutter** - https://docs.flutter.dev/get-started/install

---

## Step 1: Setup PostgreSQL Locally in pgAdmin

### 1.1 Open pgAdmin

1. Install PostgreSQL from https://www.postgresql.org/download/windows/
2. During installation, set a password for the superuser (postgres)
3. After installation, open **pgAdmin 4** from the Start menu
4. Enter the password you set during installation to unlock pgAdmin

### 1.2 Create a Login/Group Role (User)

1. In the left sidebar, expand **Servers** → **PostgreSQL** (or your local server)
2. Right-click on **Login/Group Roles** → **Create** → **Login/Group Role**

![Create Role](https://www.pgadmin.org/docs/pgadmin4/latest/images/create-role.png)

3. Fill in the following:
   - **General** tab:
     - Name: `tracely_user`
   - **Definition** tab:
     - Password: `tracely_password`
   - **Privileges** tab:
     - ✅ Can login
     - ✅ Create databases
   - Click **Save**

### 1.3 Create the Database

1. Right-click on **Databases** → **Create** → **Database**

![Create Database](https://www.pgadmin.org/docs/pgadmin4/latest/images/create-database.png)

2. Fill in the following:
   - **General** tab:
     - Database: `tracely`
   - **Definition** tab:
     - Owner: `tracely_user` (select from dropdown)
   - Click **Save**

---

## Step 2: Verify the Setup

1. Expand **Databases** in the left sidebar
2. You should see `tracely` database listed
3. Expand **Login/Group Roles**
4. You should see `tracely_user` listed

---

## Step 3: Test Database Connection

```cmd
psql -U tracely_user -d tracely -h localhost -W
```

Enter password: `tracely_password`

If successful, you'll see:
```
psql (15.x)
SSL connection ...
Type "help" for help.

tracely=>
```

---

## Step 3: Run the Backend

### Set Environment Variables

Open a new Command Prompt and run:

```cmd
set DATABASE_URL=postgres://tracely_user:tracely_password@localhost:5432/tracely?sslmode=disable
set JWT_SECRET=subi@2006
set ENCRYPTION_KEY=subi@2006
set PORT=8080
set ALLOWED_ORIGIN=http://localhost:3000
```

Or run directly with Go:

```cmd
cd g:\Tracely\backend\cmd\server
go run main.go
```

---

## Step 4: Run the Frontend

```cmd
cd g:\Tracely\frontend
flutter pub get
flutter run -d chrome
```

---

## Quick Reference: Connection String Format

```
postgres://username:password@host:port/database?sslmode=mode
```

For local development:
```
postgres://tracely_user:tracely_password@localhost:5432/tracely?sslmode=disable
```

---

## Troubleshooting

### "Connection refused" error
- PostgreSQL service not running → Start PostgreSQL service in Windows Services

### "Role does not exist" error  
- User not created → Follow Step 1 above

### "Database does not exist" error
- Database not created → Follow Step 1 above

### Port 5432 already in use
- Another PostgreSQL instance running → Use a different port or stop the other instance

