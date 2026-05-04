# Findly App

Flutter client for the [Findly Server](https://github.com/ofirShualiCodeValue/Findly-Ofir).
A single Flutter project that ships **two distinct flows** behind one auth screen,
selected by the user's `role` and enforced top-to-bottom by the routing layer:

| Role | What they see |
|---|---|
| **מעסיק** (Employer) | Single home with a horizontal calendar strip, per-day events list, and a prominent **"יצירת אירוע חדש"** FAB. Profile + notifications icons in the top-left corner. |
| **עובד** (Employee) | Two-tab home: **`הצעות עבודה`** (matched job offers) ↔ **`המשמרות שלי`** (events I applied to). Calendar strip filter, bell icon → notifications inbox. |

A role guard on each home screen redirects the user back to the right destination
if the session role doesn't match — employer-only widgets never render in an
employee session and vice versa.

---

## ⚡ Quick Start

From a fresh clone:

```bash
cd findly_app
flutter pub get

# 1. Start the backend (see Findly-Ofir README) on http://localhost:3000
# 2. Run the client. Pick the device that matches the backend address:

# Web (server on localhost:3000):
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000

# Android emulator (server on host machine — 10.0.2.2 is the loopback alias):
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000

# Physical Android device on the same Wi-Fi (replace with your PC's LAN IP):
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000
```

Default base URL when `--dart-define` is omitted: `http://10.0.2.2:3000`
(Android emulator–friendly).

---

## 📋 Prerequisites

| | |
|---|---|
| Flutter | 3.41+ (Dart 3.11+) |
| Findly server | Running at the URL passed in `--dart-define=API_BASE_URL=...` |
| Android | SDK + an AVD or a connected device. Emulator reaches the host via `10.0.2.2`. |
| Web | Any recent Chrome / Edge. ⚠️ If you change ports across runs, hard-refresh (Ctrl+Shift+R) to bypass the cached bundle. |

Native dependencies that may need platform configuration:

- **`image_picker`** — gallery/camera. Web works out of the box.
- **`geolocator`** — GPS lookup for the employee's home location.
  Android permissions already declared in
  [`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml).
  iOS would also need `NSLocationWhenInUseUsageDescription` in `Info.plist`
  before targeting iOS.

---

## 🧭 The two flows

### Employer

1. **Auth** → SMS OTP. New employers default to a blank business profile;
   no first-time wizard.
2. **Home** — calendar strip + events for the selected day.
3. **Create Event** — single form (name, type, area, date, budget). Saves as
   **draft** by default (orange "טיוטה" pill, invisible to workers).
4. **Event Details** has three tabs:
   - **הודעות כלליות** — broadcast history.
   - **משמרות** — list of shifts. "**הוסף משמרת**" button opens a sheet for
     date, start/end times (server enforces 6–12 hours per shift),
     on-site contact, and per-role staffing requirements
     (e.g. "2 × עובד הקמה + 1 × שוזר פרחים").
   - **עובדים** — applicants list with capacity banner, filters
     (status / sort / min-rating), per-row star rating, and a
     "**דרג את העובד**" button on completed approved shifts.
5. **Publish** — when the draft has its shifts, the bottom CTA flips to
   **"פרסם אירוע"**. After publish, workers in the matching sub-categories
   see it in their feed.
6. **Bell icon** → employer notification inbox (system events,
   `application_approved`, `employee_cancelled`, etc.).
7. **Profile icon** → edit business details. Logout drops the session.

### Employee

1. **Auth** → SMS OTP, **role picker** (מעסיק / עובד). Backend keeps the
   role permanent: trying to log into the same phone with a different
   role returns `ROLE_MISMATCH` and the client shows a popup asking
   whether to log in with the existing role instead.
2. **First-time registration wizard** (4-step PageView):
   - **בואו נכיר קצת** — first/last name, year-of-birth wheel picker,
     home city, work mode (`שכיר/ה` / `פרילנסר/ית`).
     **18+ check runs here** — under 18 gets a branded popup and can't
     advance.
   - **תמונת פרופיל** — gallery / camera / "דלג" (skip).
   - **איזה תחומים מתאימים לך?** — multi-select industries (chips).
   - **תת-תחומים** — for each picked industry, the user adds the specific
     roles they fill (e.g. florist, mixer). Plus location range slider
     and base hourly rate.
3. **Home** — segmented control:
   - **`הצעות עבודה`** — events whose **shift staffing** matches one of
     the employee's sub-categories, within their location range, paying at
     least the base rate, and not yet applied to or dismissed.
     Cards show real **shift** times (events span the whole day; the
     shift carries the actual working window).
   - **`המשמרות שלי`** — every event the employee has any application on.
     Status badge and "דווח שעות" / "ביטול מועמדות" actions per state.
4. **Apply** — proposed_amount pre-fills with `base_hourly_rate × shift_hours`
   so the worker can confirm or adjust.
5. **Cancel application** — within 48 h of the shift the server returns
   `CANCELLATION_POLICY_LATE`; the client shows a warning popup with the
   policy threshold and the time remaining, and re-issues the cancel
   with `?force=true` if the worker confirms.
6. **Bell icon** → notifications inbox (broadcasts from the employer
   appear here, with the sender business name + logo).

---

## 🎨 Branded popups

All in-app dialogs use a single helper —
[`widgets/findly_alert.dart`](lib/widgets/findly_alert.dart) —
that renders the rounded white card with the gradient circle badge from
the Figma. Use it instead of `showDialog`+`AlertDialog`:

```dart
await showFindlyAlert(
  context,
  badge: FindlyAlertBadge.ageBadge,                        // or .icon(Icons.warning)
  title: 'מצטערים אבל לא ניתן להמשיך בהרשמה',
  message: 'Findly מיועדת בשלב זה למשתמשים מגיל 18 ומעלה.',
  actions: [
    FindlyAlertAction(label: 'הבנתי'),                     // primary, dark
    FindlyAlertAction(label: 'ביטול', primary: false),     // text button
  ],
);
```

Returns the index of the tapped action, or `null` on dismiss.

---

## 📁 Folder structure

```
lib/
├── main.dart                         # entry, RTL Hebrew, splash → role-routed home
├── config.dart                       # API base URL (overridable at build via --dart-define)
├── api/
│   ├── client.dart                   # Dio + ApiException with errorCode + data
│   ├── auth_api.dart                 # SMS request / verify
│   ├── shared_api.dart               # /shared/categories, /shared/areas, /shared/industries
│   ├── employer_api.dart             # events, shifts, applications, ratings, capacity, notifications
│   └── employee_api.dart             # profile, events feed, apply, hours, notifications inbox
├── store/
│   └── auth_store.dart               # ChangeNotifier — token + user, persisted via shared_preferences
├── services/
│   └── location_service.dart         # geolocator wrapper (permission + service-on)
├── screens/
│   ├── splash.dart
│   ├── auth/
│   │   ├── phone_entry.dart          # phone + role picker + first name
│   │   └── otp_verify.dart           # 6-digit OTP, dev_code pre-filled
│   ├── employer/
│   │   ├── home.dart                 # calendar + events list + Create Event FAB + role guard
│   │   ├── create_event.dart         # event form (saves as draft)
│   │   ├── event_details.dart        # 3-tab details + shifts + applicants + ratings + publish
│   │   ├── notifications.dart        # employer inbox tab
│   │   └── profile.dart              # business details + logout
│   └── employee/
│       ├── home.dart                 # segmented offers/shifts + role guard
│       ├── profile_complete.dart     # 4-step registration wizard
│       ├── profile_details.dart      # personal details + avatar + industries dialog
│       ├── profile_tab.dart          # bottom-tab profile entry point
│       └── notifications.dart        # employee inbox
└── widgets/
    ├── findly_alert.dart             # branded popup (use everywhere)
    ├── calendar_strip.dart           # 14-day horizontal calendar (employer + employee)
    ├── error_view.dart
    ├── empty_state.dart
    ├── confirm_modal.dart
    ├── findly_logo.dart
    └── gradient_background.dart
```

---

## 🔍 Common test flow

1. Start the server. Make sure migrations + seeds ran.
2. Run `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000`.
3. Open two browser windows, one as employer and one (incognito) as employee.
4. **Employer:** create a draft event, add a shift with a staffing requirement
   that matches a sub-category the employee will pick (e.g. "מיקסר/ית"),
   then publish.
5. **Employee:** register with first/last name, year of birth, city, pick the
   matching industry + sub-category, finish wizard.
6. **Employee:** the published event appears under "הצעות עבודה" with the
   real shift times. Tap "מעניין אותי" — the dialog pre-fills
   `base_hourly_rate × shift_hours`. Send.
7. **Employer:** the application appears in the עובדים tab (with the
   capacity banner updating). Approve.
8. After the shift's `end_at`, the employee can "דווח שעות" and the
   employer can rate them.

---

## 🐛 Troubleshooting

| Symptom | Fix |
|---|---|
| `Failed to load resource: 500` on `/sms/request` | Backend probably has bad data — see backend logs. Often a malformed phone (must be a real IL mobile pattern). |
| Nothing happens on the auth screen | Backend isn't reachable. Verify `API_BASE_URL` matches the device — `10.0.2.2` for Android emulator, `localhost` for web, LAN IP for physical device. |
| Old UI keeps showing after a code change | Flutter web caches the JS bundle. Hard refresh (Ctrl+Shift+R) or use a different `--web-port=NNNN`. |
| Year-of-birth wheel picker won't scroll on Chrome | Already fixed via a custom `ScrollBehavior` that enables mouse drag — make sure you're on the latest commit. |
| Existing phone, but I want to test the other role | The backend returns `ROLE_MISMATCH` by design. Use a different phone, or delete the user from the DB (`DELETE FROM users WHERE id=N`). |

---

## 🚧 Status

Implements the spec phases delivered so far:

- ✅ Auth + role-gated routing
- ✅ Employee multi-step registration (18+ gate, industries + sub-categories,
  geolocator, image_picker)
- ✅ Employer event creation as draft → publish flow
- ✅ Shift CRUD with staffing requirements + 6–12h validation
- ✅ Job-offer matching by shift staffing, distance (with employer fallback),
  base rate
- ✅ Apply + 48h cancellation policy + report-hours
- ✅ Employer applicant filtering, ratings, capacity alerts
- ✅ One-way announcements (employer broadcast → employee inbox)

Not yet covered on the client:

- iOS platform configuration (`Info.plist` permissions)
- Real push notifications (FCM/APNs — Phase 6 on the server side too)
- Avatar/logo upload progress UI
