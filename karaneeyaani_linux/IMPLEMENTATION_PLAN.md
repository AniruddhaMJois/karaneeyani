# Linux Implementation Plan: Karaneeyaani

This implementation plan details the architecture, tech stack, feature workflows, and deployment procedures for the **Linux Desktop** edition of Karaneeyaani.

---

## 1. Native Linux Tech Stack

| Component | Technology / Library | Details |
| :--- | :--- | :--- |
| **Framework & Language** | Flutter 3.24+ / Dart 3.5+, C++14, GTK+ 3.0 | Core Flutter Linux Desktop runner |
| **Build System** | CMake 3.10+, Ninja build, GCC or Clang, PkgConfig | Native Linux ELF binary compilation |
| **Local Storage** | XDG Base Directory Specification | `$XDG_DATA_HOME/karaneeyaani/karaneeyaani_store.json` (default: `~/.local/share/karaneeyaani/`) |
| **Key-Value & Auth Tokens** | `shared_preferences_linux` / `libsecret` | Local configuration and salted SHA-256 PIN hash storage |
| **Desktop Notifications** | `flutter_local_notifications_linux` | D-Bus protocol (`org.freedesktop.Notifications`) |
| **Desktop Window Control** | `window_manager: ^0.3.9` | Window framing, minimum sizing (1024x720), centering, and tray minimize |
| **Hardware Input** | `KeyboardListener` / `RawKeyboardListener` | Hardware numpad (`Numpad0`-`9`) and digit keys for instant desktop PIN entry |
| **Network & Connectivity** | `connectivity_plus: ^6.1.0` | Linux NetworkManager GLib API via D-Bus |
| **Cloud Backend & Sync** | `supabase_flutter: ^2.8.0` | Cloud PostgreSQL, real-time sync, auth verification |

---

## 2. Security, Authentication & PIN Workflow

1. **First-Time Sign In / Registration (Online Required)**:
   - User provides standard username (alphanumeric, 3-20 chars) and 6-digit PIN via desktop input form.
   - Requires active network connection (verified via D-Bus NetworkManager).
   - Validates or registers user against Supabase `users_auth` table.
   - Caches username and salted SHA-256 PIN hash in the local XDG storage file.

2. **Subsequent Sign In (Offline by Default)**:
   - Desktop launches directly into the 6-digit PIN screen.
   - Supports direct typing from physical numpad/keyboard without requiring mouse clicks.
   - Validates PIN against local salt + SHA-256 hash. Zero network latency.

3. **Sign Out & Account Switching (Online Required)**:
   - Triggering "Sign Out" from the desktop sidebar opens a dialog requiring Username and 6-digit PIN.
   - Checks internet connectivity; prompts user if network is unavailable.
   - Authenticates against Supabase. On success, switches user workspace and triggers data sync.

---

## 3. "Today's Arena" & Task Extension Engine

1. **Immediate Landing**:
   - Following PIN entry, the user enters **Today's Arena** rendered inside the multi-column desktop shell.
   - Tasks created here default to today's date.

2. **"Extend This To" Feature**:
   - **Access**:
     - Configurable in the desktop inline task creator bar.
     - Accessible via an action icon at the trailing end of each task item card.
   - **Options**: Preset pills (`1 Day`, `5 Days`, `10 Days`) and `Custom Range` (Desktop Date Range Picker dialog).
   - **Duplication & Calendar Integration**:
     - Duplicates task entries across all dates in the selected range.
     - Reflects changes immediately in the desktop full-month calendar grid.
   - **Future Timeline Display**:
     - Future Timeline groups extended tasks into a single card marked with `Extended for N days`.

3. **Status Field & Daily Independent Completion**:
   - Below the task title, an inline status text field lets users record progress notes ("what has been done").
   - A dedicated **"Completed"** button is placed beneath the notes. Clicking it toggles a vibrant green fill.
   - **Extension Independence**: For extended tasks, progress text notes are copied across days, but the **"Completed"** status toggle is strictly independent per day.

---

## 4. Completed Tasks & 20-Day Auto-Purge Policy

1. **Retention & Expiration Rules**:
   - Completed tasks are recorded in Supabase (`is_completed = true`, `completed_at` timestamp).
   - If a task remains continuously completed for **20 days**, it is automatically removed from both local storage and Supabase.
   - Users can restore any completed task back to active status at its original position within the 20-day timeframe.
   - After 20 days, restore access is revoked.

---

## 5. Offline-First Dual Storage & Sync Architecture

```
[~/.local/share/karaneeyaani/karaneeyaani_store.json] 
                          │ 
               (Instant Local Write)
                          │
                 [Local Sync Queue]
                          │
         (D-Bus NetworkManager Online Event)
                          ▼
              [Supabase Cloud Database]
```

1. **Local Priority**: All mutations write to `~/.local/share/karaneeyaani/karaneeyaani_store.json` using atomic temporary file renames to guarantee data safety against crashes.
2. **Auto-Upload on Connectivity**: Whenever internet connectivity is detected, pending actions (`INSERT`, `UPDATE`, `DELETE`) are processed against Supabase.
3. **Trash Bin Permanent Deletion**:
   - Permanent deletion from Trash instantly removes the local record.
   - Adds a delete tombstone to the sync queue. Once online, the record is expunged from Supabase.

---

## 6. Linux Prerequisites & System Dependencies

On Ubuntu / Debian / Mint:
```bash
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
```

On Fedora / RHEL:
```bash
sudo dnf install -y clang cmake ninja-build pkgconf-pkg-config gtk3-devel xz-devel
```

On Arch Linux:
```bash
sudo pacman -S --needed clang cmake ninja pkgconf gtk3
```

---

## 7. Verification & Build Commands

- **Run Analysis**: `flutter analyze`
- **Run Unit Tests**: `flutter test`
- **Run Locally**: `flutter run -d linux`
- **Build Release Binary**: `flutter build linux --release`
  *(Produces executable in `build/linux/x64/release/bundle/`)*
