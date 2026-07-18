# AGENTS.md

Agent guidance for MEKAAR 3.0, a Flutter personal-safety chat app.

## Commands

```bash
flutter pub get      # Install dependencies
flutter test         # Run all tests (see Testing)
flutter run          # Run app (requires .env + Supabase, see Setup)
```

No custom lint/typecheck/format beyond Flutter defaults (`flutter analyze`, `flutter format`).

## Environment Setup

- `.env` is **gitignored and must not be committed** (contains secrets). It is also loaded as an asset in `pubspec.yaml` (line 118), so it must exist locally for any run.
- Required keys (trimmed whitespace): `SUPABASE_URL` (must end in `.supabase.co`), `SUPABASE_ANON_KEY`.
- On startup `lib/main.dart` validates config and surfaces Indonesian error messages via `SupabaseService`. A failed/missing `.env` leaves the app in a failed-init state rather than crashing.
- `.env` changes require a **full restart** (hot reload does not reload dotenv).
- For fast testing, disable Supabase "Confirm email" in Auth settings so registration is instant.

## Supabase Backend

- Migrations live in `supabase/migrations/` and **must run in numeric filename order** in the Supabase SQL Editor (no local migration runner). Current set runs `01_initial_schema.sql` → … → `12_resolve_login_email_rpc.sql`.
- Email auth must be enabled in the Supabase project.

## Architecture

```
lib/
├── core/        # constants (themes, colors), routes (AppRoutes), shared widgets
├── data/        # models, repositories, services (Supabase, WebRTC, location, storage)
└── features/    # auth, chat, guardian, map, settings, sos
```

- Entry: `lib/main.dart` → load dotenv → init Supabase → `MekaarApp` (in `lib/app.dart`) under `ProviderScope`.
- Routing centralized in `core/routes/app_routes.dart`.
- State: Riverpod (`StateNotifierProvider`, `StreamProvider`). Use `WidgetRef` in consumers; avoid raw `StatefulWidget` for business logic.
- Supabase client accessed via `Supabase.instance.client` after the init check.

## Code Conventions

- UI strings and comments are **Indonesian**.
- PIN (6-digit) stored via `flutter_secure_storage`; hashed with `crypto` SHA-256. Auto-lockout after 5 fails (30 min). Never log or echo secrets.

## Testing

- Tests in `test/`: `unit_test.dart`, `widget_test.dart`, `webrtc_signaling_test.dart`.
- Run a single file with `flutter test test/<file>.dart`.
- No integration/E2E suite configured. `webrtc_signaling_test.dart` covers WebRTC signaling.

## Platform-Specific Notes

- Linux dependency override `record_linux: 1.3.1` (pubspec.yaml line 147) — keep it; removing breaks Linux audio record.
- WebRTC and native permissions are configured for Android/iOS; check platform dirs for native config.
- Maps use OpenStreetMap via `flutter_map` (not Google Maps).
- Use `MekaarColors.surfaceOf(context)`, `surface2Of(context)`, `backgroundOf(context)` helpers instead of raw `Theme.of(context).brightness` checks for surface/background colors.
