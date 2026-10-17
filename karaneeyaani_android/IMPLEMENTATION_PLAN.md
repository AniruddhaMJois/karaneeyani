# Android Implementation Plan: Karaneeyaani

This plan defines the technical architecture for the **Android** edition of Karaneeyaani, clearly separating existing (old) features from newly introduced features.

---

## 1. Native Android Tech Stack

| Component | Technology / Library | Details |
| :--- | :--- | :--- |
| **Framework & Language** | Flutter 3.24+ / Dart 3.5+, Kotlin 2.0+, Java 17 | Android native runner |
| **Build System** | Android Gradle Plugin (AGP 8.x), Gradle Wrapper 8.4+ | `minSdkVersion: 24`, `targetSdkVersion: 34` |
| **Local Storage** | Sandboxed Internal App Storage | `/data/user/0/com.example.karaneeyaani/app_flutter/karaneeyaani_store.json` |
| **Key-Value & Auth Tokens** | `shared_preferences` / Android `EncryptedSharedPreferences` | Salted SHA-256 PIN hash and active session token |
| **Alarms & Background Timers** | `alarm: ^5.4.1` | Android `AlarmManager` with `SCHEDULE_EXACT_ALARM`, `WAKE_LOCK`, `FOREGROUND_SERVICE` |
| **System Notifications** | `flutter_local_notifications: ^18.0.1` | High-importance Android Notification Channels |
| **Biometric Auth (Optional)** | `local_auth: ^2.3.0` | Android `BiometricPrompt` API (Fingerprint / Face Unlock fallback) |
| **Network & Connectivity** | `connectivity_plus: ^6.1.0` | Android `ConnectivityManager.NetworkCallback` |
| **Cloud Backend & Sync** | `supabase_flutter: ^2.8.0` | Cloud PostgreSQL, real-time sync, auth verification |

---

## 2. Existing (Old) Features

These features are already part of the foundational codebase and remain operational:

1. **Daily Roadmap & Task Management**:
   - Create, edit, reorder, and soft-delete tasks.
   - Categorization by custom tags, time estimates, and priorities.
2. **Future Timeline Screen**:
   - Visualizing tasks scheduled for upcoming dates in chronological order.
3. **Goals Arena**:
   - Long-term and short-term goals tracking with milestones.
   - Independent from daily task extensions.
4. **Daily Routine Planner**:
   - Recurring time-blocked routines and habit checklists.
5. **Trash Bin & Restoration**:
   - Soft-deleted items move to the Trash Bin.
   - Manual restoration back to their original date/arena.
6. **Local Persistence Engine**:
   - 0ms instant UI updates backed by atomic JSON storage and `BehaviorSubject` reactive streams.
7. **Audio & Alarm Feedback**:
   - Sound playback on interactions and exact alarms for scheduled routines via `alarm`.
8. **Mobile UI Shell**:
   - Android-optimized touch navigation, drawer navigation (`custom_drawer.dart`), glass cards, bottom action sheets, and edge-to-edge system bar integration.

---

## 3. New Features

These features represent the new requirements to be integrated into the Android app:

### A. Username & 6-Digit PIN Authentication
- **First-Time Sign In / Registration (Online Required)**:
  - Input field for Username following standard username norms (`^[a-zA-Z0-9_]{3,20}$`).
  - Input field for a 6-digit numeric PIN (`^\d{6}$`).
  - Active internet connectivity verified via `connectivity_plus`.
  - Checks Supabase `users_auth` table: validates existing user or creates a new user profile.
  - Caches `username`, salted SHA-256 PIN hash, and `user_id` locally in secure storage for subsequent logins.
- **Subsequent Sign In (Offline by Default)**:
  - App opens directly to the 6-digit PIN screen.
  - Validates PIN locally against the cached salted hash. Zero internet required; 0ms unlock.
- **Sign Out & Switch Account (Online Required)**:
  - Sign Out button prompts for Username and 6-digit PIN.
  - Active internet connectivity is mandatory.
  - Validates credentials in Supabase. On success, updates local cache and downloads corresponding user data; displays an error message if invalid.

### B. "Today's Arena" Landing Screen
- Upon PIN unlock, the user lands immediately in **Today's Arena** (`DailyRoadmapScreen` mapped to `DateTime.now()`).
- All tasks created here automatically map to today's date.

### C. Task Extension Engine ("Extend This To")
- **Placement**:
  - Accessible directly during task creation.
  - Accessible on existing tasks via an extension icon at the trailing end of the task text card.
- **Scope**: Exclusive to main screen **Tasks** (does not apply to Goals).
- **Options**: Preset chips (`1 Day`, `5 Days`, `10 Days`) and `Custom Range` (Android Date Range Picker).
- **Duplication & Calendar Integration**:
  - Copies the task across all days in the designated range.
  - Displays duplicated tasks accurately in the Android monthly calendar view on each date.
- **Future Timeline Display**:
  - Extended series display as a single consolidated card in Future Timeline with the badge: `Extended for N days`.

### D. Progress Status Field & Independent Daily Completion
- **UI Layout**:
  - Below the task title, a secondary `status` text field allows the user to record progress notes ("what has been done").
  - Below the progress notes, a dedicated **"Completed"** button fills with solid green when tapped.
- **Independent Daily State**:
  - When an extended task is copied across multiple days, only the task text and the progress notes copy over.
  - The **"Completed"** state remains unique and independent for each day.

### E. Completed Tasks 20-Day Auto-Purge Policy
- Completed tasks are recorded in Supabase with `is_completed = true` and `completed_at` timestamp.
- Any task that remains continuously in the completed state for **20 days** is automatically and permanently purged from both local storage and Supabase.
- Within the 20-day window, the user can retrieve and restore the task to its original active position.
- After 20 continuous days, the restore capability expires.

### F. Offline-First Dual Storage & Automatic Cloud Sync
- **Instant Local Storage**: All modifications save to `/data/user/0/.../app_flutter/karaneeyaani_store.json` first.
- **Automatic Upload on Reconnect**:
  - As soon as Android regains internet connectivity (`connectivity_plus` detects Wi-Fi/mobile data), pending local operations are pushed to Supabase.
- **Permanent Deletion from Trash**:
  - Permanently deleting an item from the Trash Bin wipes it from local storage immediately.
  - Propagates deletion to Supabase instantly (or queues the deletion if currently offline, executing it as soon as internet returns).

---

## 4. Android Permissions (`AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
```

---

## 5. Verification & Build Commands

- **Static Analysis**: `flutter analyze`
- **Unit Tests**: `flutter test`
- **Build Release APK**: `flutter build apk --release`
- **Build App Bundle (AAB)**: `flutter build appbundle --release`
