# Alarm Overhaul and UI Fixes

This plan addresses all your requested changes for the alarm system, notifications, permissions, and database management.

## User Review Required

> [!WARNING]
> **Internet Dependency for Alarm Audio**: You requested fetching the alarm audio from the net. Because alarms must work offline, I will implement a one-time download of a high-quality alarm MP3 from the internet when the app starts, storing it locally so it works reliably even without an internet connection. Is this approach acceptable?

> [!IMPORTANT]
> **Database Clearing**: You requested to "clear everything in database now". I will write an internal script to immediately purge your Firebase tasks. Do you want me to also add a "Clear All Tasks" button in the Settings drawer for future use?

## Proposed Changes

---

### 1. pubspec.yaml

Add new dependencies required for permissions, notifications, and downloading the audio.

#### [MODIFY] pubspec.yaml
- Add `permission_handler` (for requesting precise alarm and notification permissions)
- Add `flutter_local_notifications` (for the 5-minute pre-alarm notification)
- Add `http` and `path_provider` (to download and store the network audio file)

---

### 2. Permissions & Audio Download Initialization

We need to explicitly request permissions when the user logs in and download the alarm tone.

#### [MODIFY] lib/main.dart or lib/screens/daily_roadmap_screen.dart
- Create an initialization sequence that triggers immediately after login:
  - Uses `permission_handler` to request `Permission.notification` and `Permission.scheduleExactAlarm`.
  - Checks if the network alarm audio is already downloaded. If not, fetches it using `http` and saves it to the device's application documents directory.

---

### 3. Pre-Alarm Notifications & Alarm Logic

Fix the alarm timing so the alarm rings at the exact time, and a notification appears 5 minutes prior.

#### [MODIFY] lib/widgets/task_creation_sheet.dart
- Revert the 5-minute subtraction from the main `AlarmSettings`. The alarm will now ring exactly at the user-specified time.
- Update the alarm to use the newly downloaded absolute file path for the audio instead of the local asset.
- Implement `flutter_local_notifications` to schedule a standard push notification exactly 5 minutes before the alarm time.

---

### 4. Full-Screen Alarm & Snooze Features

Create a dedicated, waking screen for when the alarm fires.

#### [MODIFY] lib/screens/daily_roadmap_screen.dart
- Upgrade the current `AlertDialog` to a rich, full-screen overlay that appears when `Alarm.ringStream` fires.
- Add a dropdown menu to select "Snooze Duration" (e.g., 5 mins, 10 mins, 15 mins).
- Add a "SNOOZE" button that stops the current alarm and schedules a new one based on the selected duration.
- Add a "DISMISS" button to permanently stop the alarm.

---

### 5. Undo SnackBar Fix

The Undo popup is not dismissing properly because it gets overridden or stuck by conflicting Snackbar scopes.

#### [MODIFY] lib/screens/daily_roadmap_screen.dart
- Change `ScaffoldMessenger.of(context).clearSnackBars();` to `hideCurrentSnackBar()` and explicitly enforce the `Duration(seconds: 4)` using a delayed Future if necessary to prevent the widget tree from keeping it alive indefinitely.

---

### 6. Database Clear Script

#### [NEW] scripts/clear_db.dart (or direct execution)
- I will execute a script on my end to query your user ID from Firebase and wipe all task documents under your `userId` collection.

## Verification Plan

### Automated/Code Verification
- Ensure `pubspec.yaml` resolves all new packages without conflicts.
- Verify `flutter run` compiles successfully with the new Android local notification configurations.

### Manual Verification
- Ask the user to verify the first-time permission prompts appear correctly.
- Test that creating an alarm schedules the 5-minute pre-notification.
- Test that the alarm rings at the exact time and displays the snooze/dismiss options.
