# Running the Frontend

## Option 1: Direct Flutter Run (Recommended for Development)

To run the frontend in development mode with hot reload:

```bash
cd g:\Tracely\frontend
flutter run -d edge
```

Or if Chrome works better on your system:

```bash
flutter run -d chrome
```

## Option 2: Already Running (Current Setup)

The frontend is already built and served at:
- **URL**: http://localhost:3000
- **Backend**: http://localhost:8080

To see changes after editing code:
1. Rebuild: `flutter build web`
2. Refresh browser

## Option 3: VS Code Debugging

1. Open the project in VS Code
2. Install the "Flutter" extension
3. Press F5 or click "Run" > "Start Debugging"

## Troubleshooting Flutter Run

### "Connection closed before full header was received"
- Try using a different browser: `flutter run -d edge`
- Or serve the built web files instead (see below)

### Alternative: Serve Built Web Files

```bash
# After making changes, rebuild:
cd g:\Tracely\frontend
flutter build web

# Serve with Python (already running at port 3000):
# Just rebuild and refresh the browser!
```

