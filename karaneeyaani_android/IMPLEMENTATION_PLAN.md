# Android Implementation Plan: Karaneeyaani

This implementation plan details the architecture, tech stack, feature workflows, and deployment procedures for the **Android** edition of Karaneeyaani.

---

## 1. Native Android Tech Stack

| Component | Technology / Library | Details |
| :--- | :--- | :--- |
| **Framework & Language** | Flutter 3.24+ / Dart 3.5+, Kotlin 2.0+, Java 17 | Core Flutter Android runner |
| **Build System** | Android Gradle Plugin (AGP 8.x), Gradle Wrapper 8.4+ | `minSdkVersion: 24` (Android 7.0), `targetSdkVersion: 34` (Android 14) |
| **Local Storage** | Sandboxed Internal App Storage | `/data/user/0/com.example.karaneeyaani/app_flutter/karaneeyaani_store.json` |
| **Key-Value & Auth Tokens** | `shared_preferences` / Android `EncryptedSharedPreferences` | Salted SHA-256 PIN hash and active session token |
| **Alarms & Background Timers** | `alarm: ^5.4.1` | Android `AlarmManager` with `SCHEDULE_EXACT_ALARM`, `WAKE_LOCK`, `FOREGROUND_SERVICE` |
| **System Notifications** | `flutter_local_notifications: ^18.0.1` | High-importance Android Notification Channels (`notification_channel_id: 'karaneeyaani_tasks'`) |
| **Biometric Auth (Optional)** | `local_auth: ^2.3.0` | Android `BiometricPrompt` API (Fingerprint / Face Unlock fallback) |
| **Network & Connectivity** | `connectivity_plus: ^6.1.0` | Listens to Android `ConnectivityManager.NetworkCallback` |
| **Cloud Backend & Sync** | `supabase_flutter: ^2.8.0` | Cloud PostgreSQL, real-time sync, auth verification |

---

## 2. Security, Authentication & PIN Workflow

1. **First-Time Sign In / Registration (Online Required)**:
   - Validates username against general username norms (`^[a-zA-Z0-9_]{3,20}$`).
   - Requires 6-digit numeric PIN (`^\d{6}$`).
   - Checks device internet connectivity via `connectivity_plus`. If disconnected, informs user that internet is mandatory for initial setup.
   - Verifies against Supabase `users_auth` table:
     - If user exists, validates PIN hash or prompts for correct credentials.
     - If user does not exist, registers new user and stores username and salted SHA-256 PIN hash.
   - Caches `username`, salted PIN hash, and `user_id` locally in secure storage for offline logins.

2. **Subsequent Sign In (Offline by Default)**:
   - The user opens the app and directly sees the 6-digit PIN pad.
   - Compares the entered PIN against the locally stored salted SHA-256 hash.
   - No internet connection required. Access granted immediately (0ms latency).

3. **Sign Out & Account Switching (Online Required)**:
   - Clicking "Sign Out" brings up a prompt requiring Username and 6-digit PIN.
   - Internet connection is strictly verified.
   - Checks Supabase for the specified credentials. If valid, switches local session to that user and triggers background sync. If invalid, displays a clear error message.

---

## 3. "Today's Arena" & Task Extension Engine

1. **Immediate Landing**:
   - Upon unlocking via PIN, user enters directly into **Today's Arena** (`DailyRoadmapScreen` mapped to `DateTime.now()`).
   - Any task created here is automatically stamped with `target_date = today`.

2. **"Extend This To" Feature**:
   - **Locations**:
     - Visible directly in the task creation dialog/input row.
     - Accessible on created tasks via an extension icon located at the end of the task text card.
   - **Options**: Preset chips (`1 Day`, `5 Days`, `10 Days`) and `Custom Range` (Android Date Range Picker).
   - **Duplication & Calendar Mapping**:
     - When a task is extended to $N$ days, the engine creates linked task instances across each selected day.
     - Each duplicated entry appears in the Android Monthly Calendar view on its respective date.
   - **Future Timeline Display**:
     - In the Future Timeline screen, grouped extended tasks render as a single consolidated card with a sub-label: `Extended for N days`.

3. **Status & Independent Completion Logic**:
   - Underneath the task title, a secondary `status` text field displays user progress notes ("what has been done").
   - A dedicated **"Completed"** button is positioned below the progress field. When tapped, it fills with solid green.
   - **Extension Isolation**: If a task is extended across multiple days, only the task text and the progress notes copy over. The **"Completed"** toggle remains independent per day.

---

## 4. Completed Tasks & 20-Day Auto-Purge Policy

1. **Retention & Deletion Rules**:
   - Completed tasks are recorded in Supabase (with `is_completed = true` and `completed_at` timestamp).
   - If a task remains continuously in the completed state for **20 days** (`now - completed_at >= 20 days`), it is automatically and permanently purged from both local storage and Supabase.
   - Within the 20-day retention window, the user can restore the task back to its active state in its original position.
   - After day 20, the restore option expires and the record is expunged.

---

## 5. Offline-First Dual Storage & Sync Architecture

```
[Local JSON File / Secure Storage] 
       │ 
   (Local CRUD - 0ms Instant UI)
       │
[Sync Queue (Local DB / Queue File)]
       │
  (Android ConnectivityManager Callback)
       ▼
 [Supabase Cloud PostgreSQL Database]
```

1. **Local Priority**: All create, edit, reorder, and completion events write atomically to `/data/user/0/.../app_flutter/karaneeyaani_store.json` first.
2. **Auto-Upload on Connectivity**:
   - `connectivity_plus` triggers background sync whenever `ConnectivityResult` transitions from `none` to `wifi` or `mobile`.
   - Sync iterates over queued operations (`INSERT`, `UPDATE`, `DELETE`) and applies them to Supabase.
3. **Trash Bin Permanent Deletion**:
   - When user triggers "Delete Permanently" from the Trash Bin, the task is immediately wiped from local storage.
   - A deletion tombstone is added to the local sync queue.
   - When online, the deletion is executed against Supabase (`DELETE FROM tasks WHERE id = ?`).

---

## 6. Android Permissions & Native Manifest Setup

Add the following permissions in `android/app/src/main/AndroidManifest.xml`:

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

## 7. Verification & Build Commands

- **Run Analysis**: `flutter analyze`
- **Run Unit Tests**: `flutter test`
- **Build Release APK**: `flutter build apk --release`
- **Build Android App Bundle (AAB)**: `flutter build appbundle --release`
