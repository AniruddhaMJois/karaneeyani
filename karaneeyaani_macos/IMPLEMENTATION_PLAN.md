# macOS Implementation Plan: Karaneeyaani

This plan defines the technical architecture for the **macOS Desktop** edition of Karaneeyaani, clearly separating existing (old) features from newly introduced features.

---

## 1. Native macOS Tech Stack

| Component | Technology / Library | Details |
| :--- | :--- | :--- |
| **Framework & Language** | Flutter 3.24+ / Dart 3.5+, Swift 5.9+, Objective-C, Cocoa | macOS native desktop runner |
| **Build System** | Xcode 15+, CocoaPods 1.14+, macOS Target: 10.15+ (Catalina+) | Hardened Runtime with App Sandbox |
| **Local Storage** | Sandboxed Application Support | `~/Library/Application Support/karaneeyaani/karaneeyaani_store.json` |
| **Key-Value & Auth Tokens** | macOS Keychain (`flutter_secure_storage`) | Hardware-secured salted SHA-256 PIN hash and session credentials |
| **Desktop Notifications** | Native `UNUserNotificationCenter` | macOS banner and alert notifications with sound |
| **Desktop Window Control** | `window_manager: ^0.3.9` | Native macOS title bar styling, centering, and min size constraints |
| **Biometric Auth (Optional)** | `local_auth: ^2.3.0` | Apple `LocalAuthentication` framework for **Touch ID** or Apple Watch unlock |
| **Network & Connectivity** | `connectivity_plus: ^6.1.0` | Apple `Network.framework` (`NWPathMonitor`) |
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
   - Sound playback on desktop actions via `audioplayers`.
8. **Desktop Shell UI**:
   - Multi-column layout (`desktop_shell_screen.dart`), permanent desktop sidebar (`desktop_sidebar.dart`), Apple keyboard shortcuts (`Cmd+N`, etc.), and responsive window framing.

---

## 3. New Features

These features represent the new requirements to be integrated into the macOS desktop app:

### A. Username & 6-Digit PIN Authentication
- **First-Time Sign In / Registration (Online Required)**:
  - Input field for Username following standard username norms (`^[a-zA-Z0-9_]{3,20}$`).
  - Input field for a 6-digit numeric PIN (`^\d{6}$`).
  - Active network connection verified via Apple's `Network.framework` (`NWPathMonitor`).
  - Validates or registers user against Supabase `users_auth` table.
  - Caches `username`, salted SHA-256 PIN hash, and `user_id` inside the **macOS Keychain**.
- **Subsequent Sign In (Offline by Default)**:
  - App opens directly to the 6-digit PIN screen (with Touch ID option).
  - Validates PIN locally against Keychain. Zero internet required; 0ms unlock.
- **Sign Out & Switch Account (Online Required)**:
  - Sign Out button prompts for Username and 6-digit PIN.
  - Active internet connectivity is mandatory.
  - Authenticates credentials against Supabase. On success, updates Keychain and downloads user data; shows clear error message if credentials fail.

### B. "Today's Arena" Landing Screen
- Upon PIN unlock, the user enters directly into **Today's Arena** rendered inside the macOS desktop shell.
- All tasks created here automatically associate with today's date.

### C. Task Extension Engine ("Extend This To")
- **Placement**:
  - Accessible during task creation in the desktop bar.
  - Accessible on existing tasks via an extension icon at the trailing end of the task text card.
- **Scope**: Exclusive to main screen **Tasks** (does not apply to Goals).
- **Options**: Preset pills (`1 Day`, `5 Days`, `10 Days`) and `Custom Range` (macOS Date Range Picker dialog).
- **Duplication & Calendar Integration**:
  - Copies the task across all days in the designated range.
  - Displays duplicated tasks accurately in the desktop monthly calendar view on each date.
- **Future Timeline Display**:
  - Extended series display as a single consolidated card in Future Timeline labeled: `Extended for N days`.

### D. Progress Status Field & Independent Daily Completion
- **UI Layout**:
  - Below the task title, an inline `status` text field allows the user to record progress notes ("what has been done").
  - Below the progress notes, a dedicated **"Completed"** button fills with bright green when clicked.
- **Independent Daily State**:
  - When an extended task is copied across multiple days, only the task text and the progress notes copy over.
  - The **"Completed"** state remains unique and independent for each day.

### E. Completed Tasks 20-Day Auto-Purge Policy
- Completed tasks are recorded in Supabase with `is_completed = true` and `completed_at` timestamp.
- Any task that remains continuously in the completed state for **20 days** is automatically and permanently purged from both local storage and Supabase.
- Within the 20-day window, the user can retrieve and restore the task to its original active position.
- After 20 continuous days, the restore capability expires.

### F. Offline-First Dual Storage & Automatic Cloud Sync
- **Instant Local Storage**: All modifications save to `~/Library/Application Support/karaneeyaani/karaneeyaani_store.json` using atomic temporary file renames.
- **Automatic Upload on Reconnect**:
  - As soon as macOS regains internet connectivity, pending local operations are pushed to Supabase.
- **Permanent Deletion from Trash**:
  - Permanently deleting an item from the Trash Bin wipes it from local storage immediately.
  - Propagates deletion to Supabase instantly (or queues the deletion if currently offline, executing it as soon as internet returns).

---

## 4. macOS Sandbox Entitlements

Ensure `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements` contain:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

---

## 5. Verification & Build Commands

- **Static Analysis**: `flutter analyze`
- **Unit Tests**: `flutter test`
- **Run Locally**: `flutter run -d macos`
- **Build Release App**: `flutter build macos --release`
