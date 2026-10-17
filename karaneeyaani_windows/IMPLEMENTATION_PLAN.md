# Windows Implementation Plan: Karaneeyaani

This implementation plan details the architecture, tech stack, feature workflows, and deployment procedures for the **Windows Desktop** edition of Karaneeyaani.

---

## 1. Native Windows Tech Stack

| Component | Technology / Library | Details |
| :--- | :--- | :--- |
| **Framework & Language** | Flutter 3.24+ / Dart 3.5+, C++17, Win32 API | Core Flutter Windows Desktop runner |
| **Build System** | Visual Studio 2022 (MSVC v143), CMake 3.20+ | Native 64-bit Windows Executable (`.exe`) |
| **Local Storage** | NTFS Atomic File Persistence | `%APPDATA%\karaneeyaani\karaneeyaani_store.json` using `.tmp` atomic replacement |
| **Key-Value & Auth Tokens** | `shared_preferences_windows` / Windows Credential Manager | Salted SHA-256 PIN hash and session state |
| **Desktop Notifications** | `flutter_local_notifications_windows` | Windows Toast Notifications (WinRT `ToastNotificationManager`) |
| **Desktop Window Control** | `window_manager: ^0.3.9` | Window sizing, title bar integration, and minimize to system tray |
| **Hardware Input** | `KeyboardListener` / `RawKeyboardListener` | Full hardware numpad (`Numpad0`-`9`) and digit keys for rapid PIN input |
| **Network & Connectivity** | `connectivity_plus: ^6.1.0` | Windows Network List Manager API (`INetworkListManager`) |
| **Cloud Backend & Sync** | `supabase_flutter: ^2.8.0` | Cloud PostgreSQL, real-time sync, auth verification |

---

## 2. Security, Authentication & PIN Workflow

1. **First-Time Sign In / Registration (Online Required)**:
   - User inputs username (alphanumeric, 3-20 characters) and 6-digit numeric PIN.
   - Internet connection is verified through Windows Network List Manager.
   - Validates or registers user against Supabase `users_auth` table.
   - Caches username and salted SHA-256 PIN hash in `%APPDATA%\karaneeyaani`.

2. **Subsequent Sign In (Offline by Default)**:
   - App launches directly into the PIN lock screen.
   - Supports hardware numpad and number keys directly.
   - Validates against the local salted SHA-256 hash. Zero network latency.

3. **Sign Out & Account Switching (Online Required)**:
   - Triggering "Sign Out" from the desktop sidebar opens a dialog requiring Username and 6-digit PIN.
   - Verifies active internet connectivity.
   - Validates credentials against Supabase. On success, clears or switches local session and downloads remote data.

---

## 3. "Today's Arena" & Task Extension Engine

1. **Immediate Landing**:
   - Following PIN entry, the user lands directly in **Today's Arena** inside the multi-column desktop layout.
   - Tasks created here automatically associate with the current date.

2. **"Extend This To" Feature**:
   - **Access**:
     - Configurable in the task creation bar.
     - Accessible via an action icon at the trailing end of each task item card.
   - **Options**: Preset pills (`1 Day`, `5 Days`, `10 Days`) and `Custom Range` (Windows Date Range Picker dialog).
   - **Duplication & Calendar Integration**:
     - Automatically creates linked task instances across all dates in the range.
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
[%APPDATA%\karaneeyaani\karaneeyaani_store.json] 
                       │ 
            (Instant Local Write)
                       │
              [Local Sync Queue]
                       │
    (Windows Network List Manager Online Event)
                       ▼
           [Supabase Cloud Database]
```

1. **Local Priority**: All mutations write to `%APPDATA%\karaneeyaani\karaneeyaani_store.json` using atomic temporary file renames.
2. **Auto-Upload on Connectivity**: Whenever internet connectivity is detected, pending actions (`INSERT`, `UPDATE`, `DELETE`) are processed against Supabase.
3. **Trash Bin Permanent Deletion**:
   - Permanent deletion from Trash instantly removes the local record.
   - Adds a delete tombstone to the sync queue. Once online, the record is expunged from Supabase.

---

## 6. Windows Prerequisites & Toolchain Setup

- **Visual Studio 2022**: Install "Desktop development with C++" workload (MSVC compiler, Windows 10/11 SDK, CMake).
- **Git for Windows**.

---

## 7. Verification & Build Commands

- **Run Analysis**: `flutter analyze`
- **Run Unit Tests**: `flutter test`
- **Run Locally**: `flutter run -d windows`
- **Build Release Binary**: `flutter build windows --release`
  *(Produces executable in `build/windows/x64/runner/Release/`)*
