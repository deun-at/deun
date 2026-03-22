# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Deun ("Simply Split Fairly") is a Flutter cross-platform expense splitting app. Users create groups, add expenses, and the app calculates who owes whom. Features friendship tracking, real-time updates, and social login.

## Build & Development Commands

```bash
flutter pub get                          # Install dependencies
dart run build_runner build              # Generate Riverpod provider code (provider.g.dart)
flutter gen-l10n                         # Generate localization files from ARB files
flutter run                              # Run in debug mode
flutter build web --release --dart-define-from-file .env_flutter/development.env  # Web build
flutter build android --release          # Android build
flutter analyze                          # Run linter
flutter test                             # Run all tests
```

After modifying `provider.dart` or any `@riverpod` annotated code, run `dart run build_runner build` to regenerate.

## Environment Setup

Requires a `.env_flutter/development.env` file with:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

These are passed via `--dart-define-from-file` at build time.

## Architecture

### Backend
- **Supabase**: PostgreSQL database, authentication (Google/GitHub/Apple OAuth), real-time subscriptions
- **Firebase**: Cloud Messaging for push notifications

### State Management
- **Riverpod** with code generation (`riverpod_annotation` + `riverpod_generator`)
- All providers defined in `lib/provider.dart` → generated `lib/provider.g.dart`
- Key notifiers: `GroupListNotifier`, `GroupDetailNotifier`, `ExpenseListNotifier`, `FriendshipListNotifier`, `UserDetailNotifier`

### Routing
- **GoRouter** with 3 stateful shell branches: `/group`, `/friend`, `/setting`
- Route config in `lib/navigation.dart`
- Nested modals for group/expense creation and editing

### Real-Time Updates
- Supabase channels subscribe to PostgresChangeEvents on tables
- Auto-reload pattern: providers listen to insert/update/delete events and refresh state

### Key Source Layout
```
lib/
├── main.dart              # Entry: Firebase + Supabase init
├── auth_gate.dart         # Auth state gating via StreamBuilder
├── navigation.dart        # GoRouter config
├── provider.dart          # All Riverpod providers (source of truth)
├── constants.dart         # Enums (ColorSeed, etc.)
├── pages/                 # Feature screens (auth/, groups/, expenses/, friends/, settings/, users/)
│   └── */\*_model.dart    # Data models per feature
├── widgets/               # Shared UI components
├── helper/helper.dart     # Utilities (date formatting, currency, snackbars)
└── l10n/                  # Localization (app_en.arb, app_de.arb)
```

### Data Flow
- Groups contain GroupMembers and Expenses
- Expenses have ExpenseEntries with percentage shares
- Groups have two modes: simplified vs. detailed expense tracking
- ExpenseListNotifier uses pagination (pageSize=20)
- Friendships track shared amounts across mutual groups

## Localization

Two languages: English (`app_en.arb`), German (`app_de.arb`). Add strings to both ARB files and run `flutter gen-l10n`.

## CI/CD

GitHub Actions deploys web builds to GitHub Pages on push to `main` (`.github/workflows/deploy_deun_web_page.yml`).

## Conventions

- Use underscore prefix for private fields
- Linting via `flutter_lints` (analysis_options.yaml)
- Multiple ScaffoldMessenger keys for per-screen snackbar control
