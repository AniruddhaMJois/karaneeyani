# iOS Implementation Plan: Karaneeyaani

This plan defines the technical architecture for the **iOS** edition of Karaneeyaani, clearly separating existing (old) features from newly introduced features.

---

## 1. Native iOS Tech Stack

| Component | Technology / Library | Details |
| :--- | :--- | :--- |
| **Framework & Language** | Flutter 3.24+ / Dart 3.5+, Swift 5.9+, Objective-C | iOS native runner |
| **Build System** | Xcode 15+, CocoaPods 1.14+, iOS Deployment Target: 14.0+ | iPhone & iPad form factors |
| **Local Storage** | Sandboxed Application Support Directory | `path_provider` pointing to `NSApplicationSupportDirectory/karaneeyaani_store.json` |
| **Key-Value & Auth Tokens** | iOS Keychain Services (`flutter_secure_storage`) | Hardware-encrypted storage for salted SHA-256 PIN hash and session data |
| **Notifications & Alarms** | `flutter_local_notifications: ^18.0.1` | Native `UNUserNotificationCenter` with scheduled local notifications |
| **Background Processing** | Background Tasks Framework (`BGAppRefreshTask`) | Periodic queue processing and sync triggers |
| **Biometric Auth (Optional)** | `local_auth: ^2.3.0` | Apple `LocalAuthentication` framework (Face ID / Touch ID fallback) |
| **Network & Connectivity** | `connectivity_plus: ^6.1.0` | Apple's `Network.framework` (`NWPathMonitor`) |
| **Cloud Backend & Sync** | `supabase_flutter: ^2.8.0` | Cloud PostgreSQL, real-time sync, auth verification |

---

## 2. Existing (Old) Features

These features are already part of the foundational codebase and remain operational:

1. **Daily Roadmap & Task Management**:
   - Create, edit, reorder, and soft-delete tasks.
   - Categorization by custom tags, time estimates, and priorities.
2. **Future Timeline Screen**:
   - Chronological visualization of future scheduled tasks.
3. **Goals Arena**:
   - Milestone tracking for short-term and long-term goals.
   - Operates independently from daily task extensions.
4. **Daily Routine Planner**:
   - Recurring time-blocked routines and habit checklists.
5. **Trash Bin & Restoration**:
   - Soft-deleted items move to the Trash Bin.
   - Manual recovery back to original dates/arenas.
6. **Local Persistence Engine**:
   - Atomic JSON storage and `BehaviorSubject` reactive streams providing 0ms UI responsiveness.
7. **Audio Feedback**:
   - Sound playback on interactions and alarms.
8. **Mobile UI Shell**:
   - iOS-tailored touch experience: Cupertino navigation styles, swipe gestures, haptic feedback, safe area management, and responsive layouts.

---

## 3. New Features

These features represent the new requirements to be integrated into the iOS app:

### A. Username & 6-Digit PIN Authentication
- **First-Time Sign In / Registration (Online Required)**:
  - Input field for Username following standard username norms (`^[a-zA-Z0-9_]{3,20}$`).
  - Input field for a 6-digit numeric PIN (`^\d{6}$`).
  - Active network connectivity verified via `connectivity_plus` (`NWPathMonitor`).
  - Validates or registers user against Supabase `users_auth` table.
  - Caches `username`, salted SHA-256 PIN hash, and `user_id` inside the **iOS Keychain**.
- **Subsequent Sign In (Offline by Default)**:
  - App opens directly to the 6-digit PIN screen (with Face ID / Touch ID option).
  - Validates PIN locally against Keychain. Zero internet required; 0ms unlock.
- **Sign Out & Switch Account (Online Required)**:
  - Sign Out button prompts for Username and 6-digit PIN.
  - Active internet connectivity is mandatory.
  - Authenticates credentials against Supabase. On success, updates Keychain and downloads user data; shows clear error message if credentials fail.

### B. "Today's Arena" Landing Screen
- Upon PIN unlock, the user lands immediately in **Today's Arena** (`DailyRoadmapScreen` tied to current date).
- All tasks created here automatically associate with today's date.

### C. Task Extension Engine ("Extend This To")
- **Placement**:
  - Accessible during task creation.
  - Accessible on existing tasks via an extension icon at the trailing end of the task text card.
- **Scope**: Exclusive to main screen **Tasks** (does not apply to Goals).
- **Options**: Preset pills (`1 Day`, `5 Days`, `10 Days`) and `Custom Range` (iOS Date Range Picker).
- **Duplication & Calendar Integration**:
  - Copies the task across all days in the designated range.
  - Displays duplicated tasks accurately in the iOS calendar view on each date.
- **Future Timeline Display**:
  - Extended series display as a single consolidated card in Future Timeline labeled: `Extended for N days`.

### D. Progress Status Field & Independent Daily Completion
- **UI Layout**:
  - Below the task title, a secondary `status` text field allows the user to record progress notes ("what has been done").
  - Below the progress notes, a dedicated **"Completed"** button fills with iOS system green when tapped.
- **Independent Daily State**:
  - When an extended task is copied across multiple days, only the task text and the progress notes copy over.
  - The **"Completed"** state remains unique and independent for each day.

### E. Completed Tasks 20-Day Auto-Purge Policy
- Completed tasks are recorded in Supabase with `is_completed = true` and `completed_at` timestamp.
- Any task that remains continuously in the completed state for **20 days** is automatically and permanently purged from both local storage and Supabase.
- Within the 20-day window, the user can retrieve and restore the task to its original active position.
- After 20 continuous days, the restore capability expires.

### F. Offline-First Dual Storage & Automatic Cloud Sync
- **Instant Local Storage**: All modifications save to sandboxed Application Support storage first.
- **Automatic Upload on Reconnect**:
  - As soon as iOS regains internet connectivity (`connectivity_plus` detects connection), pending local operations are pushed to Supabase.
- **Permanent Deletion from Trash**:
  - Permanently deleting an item from the Trash Bin wipes it from local storage immediately.
  - Propagates deletion to Supabase instantly (or queues the deletion if currently offline, executing it as soon as internet returns).

---

## 4. iOS Info.plist Configuration

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

## 5. Verification & Build Commands

- **Static Analysis**: `flutter analyze`
- **Unit Tests**: `flutter test`
- **Install Pods**: `cd ios && pod install && cd ..`
- **Build iOS (No Codesign)**: `flutter build ios --no-codesign`
- **Build Release IPA**: `flutter build ipa --release`
