# iOS Implementation Plan: Karaneeyaani

This implementation plan details the architecture, tech stack, feature workflows, and deployment procedures for the **iOS** edition of Karaneeyaani.

---

## 1. Native iOS Tech Stack

| Component | Technology / Library | Details |
| :--- | :--- | :--- |
| **Framework & Language** | Flutter 3.24+ / Dart 3.5+, Swift 5.9+, Objective-C | Core Flutter iOS runner |
| **Build System** | Xcode 15+, CocoaPods 1.14+, iOS Deployment Target: 14.0+ | Compatible with iPhone and iPad form factors |
| **Local Storage** | Sandboxed Application Support Directory | `path_provider` pointing to sandboxed `NSApplicationSupportDirectory/karaneeyaani_store.json` |
| **Key-Value & Auth Tokens** | iOS Keychain Services (`flutter_secure_storage`) | Hardware-encrypted storage for salted SHA-256 PIN hash and session data |
| **Notifications & Alarms** | `flutter_local_notifications: ^18.0.1` | Native `UNUserNotificationCenter` with scheduled local notifications and badge count updates |
| **Background Processing** | Background Tasks Framework (`BGAppRefreshTask`) | Periodic queue processing and sync triggers |
| **Biometric Auth (Optional)** | `local_auth: ^2.3.0` | Apple `LocalAuthentication` framework (Face ID / Touch ID) |
| **Network & Connectivity** | `connectivity_plus: ^6.1.0` | Listens to Apple's `Network.framework` (`NWPathMonitor`) |
| **Cloud Backend & Sync** | `supabase_flutter: ^2.8.0` | Cloud PostgreSQL, real-time sync, auth verification |

---

## 2. Security, Authentication & PIN Workflow

1. **First-Time Sign In / Registration (Online Required)**:
   - User inputs username (adhering to norms: 3-20 characters, alphanumeric and underscores) and a 6-digit numeric PIN.
   - Requires active network connection (`NWPathMonitor` verified via `connectivity_plus`).
   - Validates or registers user against Supabase `users_auth` table.
   - Caches username and salted SHA-256 PIN hash securely inside the **iOS Keychain**.

2. **Subsequent Sign In (Offline by Default)**:
   - Direct entry to the 6-digit PIN screen (with optional Face ID / Touch ID prompt via `LocalAuthentication`).
   - Validates PIN locally against Keychain.
   - Zero network round-trips; opens app instantaneously.

3. **Sign Out & Account Switching (Online Required)**:
   - Tapping "Sign Out" displays a modal requiring Username and 6-digit PIN.
   - Internet connection is mandatory.
   - Authenticates against Supabase. On success, updates local Keychain and triggers fresh database download. If credentials fail, displays a native error alert.

---

## 3. "Today's Arena" & Task Extension Engine

1. **Immediate Landing**:
   - PIN entry unlocks directly to **Today's Arena** (`DailyRoadmapScreen` tied to current device date).
   - Tasks added default to today's date.

2. **"Extend This To" Feature**:
   - **Access**:
     - Configurable during initial task creation.
     - Available after task creation via an action icon at the trailing end of the task card.
   - **Options**: Preset pills (`1 Day`, `5 Days`, `10 Days`) or `Custom Range` (iOS Cupertino Date Range Picker).
   - **Duplication & Calendar Integration**:
     - Duplicates task metadata across all days in the chosen range.
     - Automatically renders duplicated cards on the iOS Calendar view for each corresponding date.
   - **Future Timeline Display**:
     - In Future Timeline, extended series display as a single consolidated tile marked with `Extended for N days`.

3. **Status Field & Daily Independent Completion**:
   - Beneath the task title, a progress notes text field records "what has been done".
   - A dedicated **"Completed"** button is placed below the notes. When clicked, it fills with iOS system green.
   - **Independent State**: When a task is extended over multiple days, only the status text/progress note copies over. The completion state remains completely isolated per day.

---

## 4. Completed Tasks & 20-Day Auto-Purge Policy

1. **20-Day Retention Window**:
   - Completed tasks are stored in Supabase with `is_completed = true` and `completed_at` timestamp.
   - When any individual task remains in the completed state continuously for **20 days**, it is automatically deleted permanently from both local storage and Supabase.
   - Within 20 days, the user can restore the task to its original active position.
   - After 20 days, the restore option is invalidated.

---

## 5. Offline-First Dual Storage & Sync Architecture

```
[Local JSON File / iOS Keychain] 
              │ 
      (0ms Local State)
              │
    [Local Sync Action Queue]
              │
(NWPathMonitor Online Event / BGAppRefreshTask)
              ▼
   [Supabase Cloud Database]
```

1. **Immediate Local Persistence**: All mutations write atomically to the local JSON file.
2. **Auto-Upload on Connectivity**: Whenever internet connectivity is detected, pending queue operations (`INSERT`, `UPDATE`, `DELETE`) are dispatched to Supabase.
3. **Trash Bin Permanent Deletion**:
   - Permanent deletion from Trash instantly removes the local record.
   - Deletion command is queued. As soon as internet is available, the record is expunged from Supabase.

---

## 6. iOS Permissions & Info.plist Configuration

Add the following keys to `ios/Runner/Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Karaneeyaani uses Face ID for quick and secure PIN unlock.</string>
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>processing</string>
</array>
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.example.karaneeyaani.sync</string>
</array>
```

---

## 7. Verification & Build Commands

- **Run Analysis**: `flutter analyze`
- **Run Unit Tests**: `flutter test`
- **Install CocoaPods Dependencies**: `cd ios && pod install && cd ..`
- **Build iOS (No Codesign for Local Testing)**: `flutter build ios --no-codesign`
- **Build iOS Release (Archive for App Store / TestFlight)**: `flutter build ipa --release`
