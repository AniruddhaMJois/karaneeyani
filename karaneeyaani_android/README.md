# Karaneeyaani (Android & Web Edition)

A high-performance, offline-first productivity and task architecture application designed for flow state, seamless task management, and multi-day extensions.

---

## ⚡ Core Features

1. **Authentication & PIN Security**:
   - **First-Time Sign In / Registration**: Internet required. Supports username (3–20 alphanumeric characters/underscores) and a 6-digit numeric PIN verified against Supabase `users_auth`. Salted SHA-256 PIN hash and credentials are securely cached locally.
   - **Subsequent Unlocks**: Instant offline PIN pad with 0ms local verification.
   - **Switch Account / Sign Out**: Requires username and PIN, verified against Supabase before switching local profile.

2. **"Today's Arena" Landing Screen**:
   - Immediately lands on Today's Arena mapped to the current date (`DateTime.now()`). All newly created tasks default to today.

3. **Task Extension Engine ("Extend This To")**:
   - Available during task creation and on active task cards.
   - Preset chips for `1`, `5`, `10` days, and custom date range picker.
   - Consolidated timeline presentation with `Extended for N days` badges.

4. **Progress Status Field & Independent Daily Completion**:
   - Inline progress status notes under task titles ("what has been done").
   - Dedicated solid green "Completed" button.
   - For extended series, tasks copy text and progress notes across days while completion status remains strictly independent per day.

5. **20-Day Completed Auto-Purge**:
   - Completed tasks track `completed_at` timestamps.
   - Tasks residing in Completed Items for ≥ 20 days are permanently purged from local storage and Supabase.
   - Tasks can be restored to active roadmap within the 20-day window.

6. **Offline-First Dual Storage & Auto-Sync**:
   - Writes immediately to internal sandboxed storage (`karaneeyaani_store.json`), operating completely offline.
   - Auto-detects Android and Web network connectivity changes to drain mutation queues and sync with Supabase in the background.

7. **Complete Mobile Navigation & Sound Alarms**:
   - Mobile glass drawer navigation with quick access to Today's Arena, Calendar, Goals Arena, Future Timeline, Completed Tasks, Recycle Bin, and Daily Routine Planner.
   - Custom notification sound alarms integrated via `flutter_local_notifications` and `alarm`.

---

## 🛠️ Verification & Testing

```bash
# Run static analysis
flutter analyze

# Execute unit and model test suite
flutter test

# Build debug Android APK
flutter build apk --debug

# Build Web distribution
flutter build web
```

APK Location: `build/app/outputs/flutter-apk/app-debug.apk`

---

## 🗄️ Supabase Database Setup

See [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md) for full configuration details and SQL migration scripts.
