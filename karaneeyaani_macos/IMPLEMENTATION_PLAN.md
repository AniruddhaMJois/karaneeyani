# macOS Implementation Plan: Karaneeyaani

This implementation plan details the architecture, tech stack, feature workflows, and deployment procedures for the **macOS Desktop** edition of Karaneeyaani.

---

## 1. Native macOS Tech Stack

| Component | Technology / Library | Details |
| :--- | :--- | :--- |
| **Framework & Language** | Flutter 3.24+ / Dart 3.5+, Swift 5.9+, Objective-C, Cocoa | Core Flutter macOS Desktop runner |
| **Build System** | Xcode 15+, CocoaPods 1.14+, macOS Target: 10.15+ (Catalina+) | Hardened Runtime with App Sandbox |
| **Local Storage** | Sandboxed Application Support | `~/Library/Application Support/karaneeyaani/karaneeyaani_store.json` |
| **Key-Value & Auth Tokens** | macOS Keychain (`flutter_secure_storage`) | Hardware-secured salted SHA-256 PIN hash and session credentials |
| **Desktop Notifications** | Native `UNUserNotificationCenter` | macOS banner and alert notifications with sound |
| **Desktop Window Control** | `window_manager: ^0.3.9` | Native macOS title bar styling, centering, and min size constraints |
| **Biometric Auth (Optional)** | `local_auth: ^2.3.0` | Apple `LocalAuthentication` framework for **Touch ID** or Apple Watch unlock |
| **Network & Connectivity** | `connectivity_plus: ^6.1.0` | Apple `Network.framework` (`NWPathMonitor`) |
| **Cloud Backend & Sync** | `supabase_flutter: ^2.8.0` | Cloud PostgreSQL, real-time sync, auth verification |

---

## 2. Security, Authentication & PIN Workflow

1. **First-Time Sign In / Registration (Online Required)**:
   - User provides standard username (alphanumeric, 3-20 characters) and 6-digit numeric PIN.
   - Outgoing network client entitlement is used to contact Supabase (`com.apple.security.network.client`).
   - Validates or registers user against Supabase `users_auth` table.
   - Saves username and salted SHA-256 PIN hash in the macOS Keychain.

2. **Subsequent Sign In (Offline by Default)**:
   - App opens directly into the 6-digit PIN screen (with Touch ID prompt where hardware allows).
   - Validates PIN against the Keychain salt + hash. Zero network latency.

3. **Sign Out & Account Switching (Online Required)**:
   - Clicking "Sign Out" from the desktop sidebar opens a dialog requiring Username and 6-digit PIN.
   - Active network connectivity is mandatory.
   - Verifies against Supabase. On success, updates local Keychain and triggers fresh database download.

---

## 3. "Today's Arena" & Task Extension Engine

1. **Immediate Landing**:
   - Following PIN entry, the user enters **Today's Arena** rendered inside the macOS desktop shell.
   - Tasks created here default to today's date.

2. **"Extend This To" Feature**:
   - **Access**:
     - Configurable in the task creation bar.
     - Accessible via an action icon at the trailing end of each task item card.
   - **Options**: Preset pills (`1 Day`, `5 Days`, `10 Days`) and `Custom Range` (macOS Date Range Picker dialog).
   - **Duplication & Calendar Integration**:
     - Duplicates task entries across all dates in the selected range.
     - Displays duplicated tasks across the full desktop calendar grid.
   - **Future Timeline Display**:
     - Future Timeline consolidates extended tasks into a single card marked with `Extended for N days`.

3. **Status Field & Daily Independent Completion**:
   - Below the task title, a progress notes text field allows users to record "what has been done".
   - A dedicated **"Completed"** button is placed beneath the notes. Clicking it toggles a bright green fill.
   - **Extension Independence**: For extended tasks, the progress text note is copied across days, but the **"Completed"** state remains strictly independent per day.

---

## 4. Completed Tasks & 20-Day Auto-Purge Policy

1. **Retention & Expiration Rules**:
   - Completed tasks are recorded in Supabase (`is_completed = true`, `completed_at` timestamp).
   - If a task remains continuously in the completed state for **20 days**, it is automatically removed from both local storage and Supabase.
   - Users can restore any completed task back to active status at its original position within the 20-day timeframe.
   - After 20 days, restore access is revoked.

---

## 5. Offline-First Dual Storage & Sync Architecture

```
[~/Library/Application Support/karaneeyaani/karaneeyaani_store.json] 
                               │ 
                     (Instant Local Write)
                               │
                      [Local Sync Queue]
                               │
               (NWPathMonitor Online Event Callback)
                               ▼
                   [Supabase Cloud Database]
```

1. **Local Priority**: All mutations write to sandboxed application support storage using atomic temporary file renames.
2. **Auto-Upload on Connectivity**: Whenever internet connectivity is detected, pending actions (`INSERT`, `UPDATE`, `DELETE`) are processed against Supabase.
3. **Trash Bin Permanent Deletion**:
   - Permanent deletion from Trash instantly removes the local record.
   - Adds a delete tombstone to the sync queue. Once online, the record is expunged from Supabase.

---

## 6. macOS Sandbox Entitlements Setup

Verify that `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements` have:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

---

## 7. Verification & Build Commands

- **Run Analysis**: `flutter analyze`
- **Run Unit Tests**: `flutter test`
- **Run Locally**: `flutter run -d macos`
- **Build Release App**: `flutter build macos --release`
  *(Produces `.app` bundle in `build/macos/Build/Products/Release/`)*
