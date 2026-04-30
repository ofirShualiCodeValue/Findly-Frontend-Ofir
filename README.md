# Findly App

Flutter client for the [Findly Server](https://github.com/ofirShualiCodeValue/Findly-Ofir). One project, two flows — selectable at signup time:

- **Employer** — create events, review applicants, approve/reject, send notifications, manage profile.
- **Employee** — browse open events, submit a proposal with a price, track own applications.

## Prerequisites

- Flutter 3.41+ (Dart 3.11+)
- Findly server running (default: `http://localhost:3000`)
- For Android emulator: Android SDK + an AVD or a connected device. Emulator reaches the host machine via `10.0.2.2`.

## Run

```bash
cd findly_app
flutter pub get

# web (server on localhost:3000):
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000

# android emulator (server on host machine):
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000

# physical device on same Wi-Fi (replace with your PC's LAN IP):
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000
```

Default base URL when no `--dart-define` is passed is `http://10.0.2.2:3000` (Android emulator–friendly).

## Test flow (full)

1. Phone screen → enter `0536298799` (or any valid IL mobile), pick `מעסיק` or `עובד`, tap "שליחת קוד אימות".
2. The server returns `dev_code` in development, the OTP screen pre-fills it. Tap "אישור והיכנס".
3. **Employer:** home shows your events. Tap "+ יצירת אירוע חדש". Fill form, save.
4. **Employee:** sign in (different phone) → "אירועים" tab → tap "הגש מועמדות", enter price, send.
5. Switch back to **Employer:** tap event → see the new application → "אישור" or "דחייה".
6. Send a notification to approved employees with the airplane button on the event detail screen.

## Folder structure

```
lib/
├── main.dart                         # entry, RTL Hebrew theme, role-based home
├── config.dart                       # API base URL (overridable at build)
├── api/
│   ├── client.dart                   # Dio with auth interceptor + ApiException
│   ├── auth_api.dart
│   ├── employer_api.dart
│   └── employee_api.dart
├── store/
│   └── auth_store.dart               # ChangeNotifier: token + user, persisted via shared_preferences
├── screens/
│   ├── auth/
│   │   ├── phone_entry.dart          # phone + role + name + send-OTP
│   │   └── otp_verify.dart           # 6-digit code input, pre-filled in dev
│   ├── employer/
│   │   ├── home.dart                 # events list, FAB to create
│   │   ├── create_event.dart         # full form + taxonomies dropdown
│   │   ├── event_details.dart        # details + applications list + send notification + cancel
│   │   └── profile.dart              # business name / VAT / address edit
│   └── employee/
│       └── home.dart                 # tab 1: browse open events. tab 2: my applications
└── widgets/
    └── error_view.dart
```

## Status

This client targets the v0.1 backend (Phase 5 complete). It **does not yet** cover:

- Notification inbox screen for employer (`GET /v1/employer/notifications`)
- Notification history view per event
- Logo upload (server endpoint exists at `POST /v1/employer/profile/logo`)
- Mark notifications as read
- Employee profile editing
- Real push notifications (FCM/APNs — Phase 6)
