# Battly Product Setup

This workspace contains three projects:

- `backend` - Laravel API at `http://localhost:8888/api`
- `zone` - Next.js admin portal at `http://localhost:3000`
- `app` - Flutter mobile client

## Prerequisites

- Docker Desktop
- Flutter SDK with Android tooling
- Node.js 20 or newer
- PHP/Composer are optional when using Docker for the backend

## Backend

The backend is configured for PostgreSQL, Redis, and MinIO through Docker Compose.

```powershell
cd backend
docker compose up -d --build
docker compose exec app php artisan migrate --seed
docker compose exec app php artisan storage:link
```

API health check:

```powershell
curl http://localhost:8888/api/tournaments
```

Seeded admin login:

- Email: `ganesh@battly.zone`
- Password: `password`

## Admin Portal

### Docker (recommended — runs with the API)

From `backend/`:

```powershell
# Local
.\deploy.ps1

# Production (goscrim) — Linux server
export NEXT_PUBLIC_API_BASE_URL=https://api.goscrim.live/api
export NEXT_PUBLIC_BACKEND_BASE_URL=https://api.goscrim.live
./deploy.sh
```

Zone admin: `http://localhost:3000`

### Local dev (without Docker)

```powershell
cd zone
copy .env.example .env.local
npm install
npm run dev
```

Open `http://localhost:3000`.

For production, set:

```env
NEXT_PUBLIC_API_BASE_URL=https://api.example.com/api
NEXT_PUBLIC_BACKEND_BASE_URL=https://api.example.com
```

## Flutter App

```powershell
cd app
flutter pub get
flutter run
```

Backend URL defaults:

- Android emulator: `http://10.0.2.2:8888`
- Windows/iOS simulator/desktop: `http://127.0.0.1:8888`

For a physical Android device on the same Wi-Fi:

```powershell
flutter run --dart-define=BATTLY_PHYSICAL_DEVICE_IP=<your-lan-ip>
```

For production/staging:

```powershell
flutter build apk --release --dart-define=BATTLY_API_BASE_URL=https://api.example.com
```

## Notes Before Release

- Replace the debug Android signing config with a release keystore.
- Replace Firebase and Google sign-in config with the production Firebase project.
- Replace eSewa test values in `backend/.env` with production merchant credentials.
- Upload real app assets under `app/assets/background`, `app/assets/logo`, and `app/assets/img`.
