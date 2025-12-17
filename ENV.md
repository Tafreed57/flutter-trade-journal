# Environment Configuration

This document explains how to configure environment variables for the Trading Journal app.

## Quick Start

### Development (using .env file)

1. Create a `.env` file in the project root:

```env
FINNHUB_API_KEY=your_finnhub_api_key_here
```

2. The `.env` file is gitignored and will NOT be committed.

---

## Environment Variables

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `FINNHUB_API_KEY` | No | Finnhub API key for real market data | Falls back to mock data |
| `API_BASE_URL` | No | Override API base URL | https://finnhub.io/api/v1 |
| `WS_URL` | No | Override WebSocket URL | wss://ws.finnhub.io |

---

## Configuration Methods

### Method 1: .env File (Development)

Best for local development. Create `.env` in project root:

```env
FINNHUB_API_KEY=sandbox_xxxxxx
```

### Method 2: --dart-define (CI/CD & Builds)

Pass environment variables at build time:

```bash
# Single variable
flutter build web --dart-define=FINNHUB_API_KEY=pk_live_xxxxx

# Multiple variables
flutter build apk \
  --dart-define=FINNHUB_API_KEY=pk_live_xxxxx \
  --dart-define=API_BASE_URL=https://api.example.com

# From file (useful for CI)
flutter build web --dart-define-from-file=env.json
```

### Method 3: env.json (CI/CD)

Create `env.json` (gitignored):

```json
{
  "FINNHUB_API_KEY": "pk_live_xxxxx",
  "API_BASE_URL": "https://api.example.com"
}
```

Build with:
```bash
flutter build web --dart-define-from-file=env.json
```

---

## Platform-Specific Notes

### Web

Environment variables are embedded in the JavaScript bundle at build time.
Never expose sensitive keys in web builds that will be publicly accessible!

For production web, consider:
- Using a backend proxy for API calls
- Firebase Cloud Functions as an API gateway

### Android

- Variables are embedded in the APK
- Prefer backend proxies for sensitive keys

### iOS/macOS

- Variables are embedded in the app bundle
- Use Keychain for runtime secrets

### Desktop (Windows/Linux)

- Variables are embedded in the executable
- Can also read from system environment at runtime

---

## Security Best Practices

1. **Never commit secrets** - `.env`, `env.json`, and key files are gitignored
2. **Use backend proxies** - Don't embed production API keys in client apps
3. **Different keys per environment** - Use sandbox keys for development
4. **Rotate keys regularly** - If exposed, regenerate immediately
5. **Audit git history** - Secrets accidentally committed remain in history

---

## CI/CD Integration

### GitHub Actions Example

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      
      - name: Build Web
        run: |
          flutter build web --release \
            --dart-define=FINNHUB_API_KEY=${{ secrets.FINNHUB_API_KEY }}
```

### Local Build Script

Create `scripts/build-release.ps1`:

```powershell
# Load secrets from 1Password, Vault, etc.
$env:FINNHUB_API_KEY = op read "op://Vault/Finnhub/api-key"

flutter build web --release --dart-define=FINNHUB_API_KEY=$env:FINNHUB_API_KEY
```

---

## Fallback Behavior

The app gracefully handles missing configuration:

| Missing Config | Fallback |
|----------------|----------|
| `FINNHUB_API_KEY` | Uses mock market data |
| Firebase | Runs in offline mode |

This ensures the app works for development without any external setup.

