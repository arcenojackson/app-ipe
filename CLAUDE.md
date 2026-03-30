# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

IPE Flutter is a church management app for Igreja Presbiteriana do Brasil (IPB Estreito, Florianópolis/SC). It handles member management, event scheduling, service scales/rosters, chat with mentions, push notifications, and music evaluations. The app is in Portuguese (pt_BR).

## Commands

### Flutter (frontend)
```bash
flutter pub get                    # Install dependencies
flutter analyze                    # Static analysis
flutter test                       # Run all tests
flutter test path/to/file_test.dart --plain-name "test name"  # Run single test
flutter build apk --release        # Android release build
flutter build ios --release        # iOS release build (requires macOS + Xcode)
dart format .                      # Format code
```

### Firebase Functions (backend)
```bash
cd functions && npm install        # Install dependencies
cd functions && npm run lint       # Lint TypeScript
cd functions && npm run build      # Compile TS → JS
firebase emulators:start --only functions  # Local testing
firebase deploy --only functions   # Deploy to production
```

## Architecture

### Frontend: Flutter + Provider

**State management:** Provider with `ChangeNotifier`. `AppState` (`lib/src/shared/state/app_state.dart`) is the central auth state, provided via `ChangeNotifierProvider` in `main.dart`. Repositories are injected as `Provider.value` at the root `MultiProvider`.

**Navigation:** `MaterialApp` with imperative navigation (no GoRouter). Auth state drives top-level routing in `app.dart` — bootstrapping shows splash, unauthenticated shows login, authenticated shows `HomeShell`.

**Module structure** (`lib/src/modules/`): Each module follows `data/` (repositories), `models/`, `presentation/` (pages/widgets) layers:
- `auth` — Firebase Auth (email/password, Google, Apple Sign-In), user model, settings
- `events` — Event/service management, agenda, calendar, planning, weekly team assignments
- `musics` — Music library management
- `music_evaluations` — Music evaluation/rating system
- `societies` — Church societies/groups
- `people` — Member management
- `notifications` — FCM push notifications, preferences
- `holyrics` — Holyrics projection software integration (in development)
- `home` — HomeShell with bottom nav (agenda, planning, calendar, musics tabs)

**Shared layer** (`lib/src/shared/`): Theme (`app_theme.dart`), reusable widgets, services (Pexels client, session storage), utilities.

**Core layer** (`lib/src/core/`): `ApiClient` (HTTP via `http` package), `FirebaseConfig`, `AppConfig`, `AppException`.

### Backend: Firebase Functions (TypeScript)

Single entry point: `functions/src/index.ts`. Key triggers:
- **Chat notifications:** `onMessageCreated` / `onSocietyMessageCreated` — sends push to mentioned users
- **Scale notifications:** `onServicePeopleUpdated` / `onServiceStepsUpdated` — notifies assigned members
- **Scheduled reminders:** `fridayLiturgyReminder`, `mondayPrayerMeetingReminder`, `eloAvailabilityReminder`

### Firestore Collections

- `users/{userId}` — profile, `fcmToken`, `disabled_notifications` preferences
- `services/{eventId}` — events with teams, people assignments, steps (music list)
- `societies/{societyId}` — church groups with board members
- `*/messages/{messageId}` — subcollections for chat messages under services and societies

## Key Patterns

- **Repository pattern:** Each module's `data/` folder contains a repository class that wraps Firestore or ApiClient calls. Repositories are instantiated in `main.dart` and provided via Provider.
- **Firestore direct access:** Most repositories use `cloud_firestore` directly (not through ApiClient). ApiClient exists for external HTTP APIs.
- **Token refresh:** `_AppHome` in `app.dart` listens to app lifecycle and refreshes Firebase ID token on resume to avoid permission-denied errors.
- **Firestore collection names:** Changing collection/route names requires coordinated updates in both Flutter code and Firebase Functions.

## Memory

### Me
**Jackson Felipe** — `jackson.f205@gmail.com`
Notion user ID: `f3034d8a-427a-4dda-b587-c582ff147df4`

### Preferences
- Ao criar tasks no Notion, sempre definir **Responsável** como Jackson Felipe (ID acima)