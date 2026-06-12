# Alarm Overhaul & UI Fixes Walkthrough

I have completely overhauled the alarm system and UI based on your feedback. Here is everything that has been implemented and how it works:

## 1. Network Audio Download
The app now automatically downloads a reliable alarm tone from the internet the very first time you open it. This audio is saved directly to your phone's storage. This ensures that even if your phone loses its internet connection overnight, your alarm will reliably ring using the locally saved audio.

## 2. Notification System
When you set a task alarm, the app now registers two separate events:
- **Pre-Alarm Warning:** Exactly **5 minutes before** the scheduled time, a silent system notification will appear on your lock screen saying "Task starts in 5 minutes!".
- **The Main Event:** At the exact requested time, the main alarm will sound.

## 3. Full-Screen Wake Up
When the alarm rings, the app will now push an immersive, full-screen "Wake Up" interface instead of the tiny dialog box. This screen features:
- A pulsating alarm icon.
- A **SNOOZE** button with a customizable dropdown (5, 10, 15, or 30 minutes).
- A **DISMISS** button to stop the alarm permanently.

## 4. Clear Database Feature
As requested, you now have complete control over your database.
1. Open the side menu (Drawer).
2. Tap the new orange **"Clear All Tasks"** button.
3. Confirm the warning popup to instantly wipe every single task from your Firebase account.

## 5. Undo Popup Fix
The "UNDO" popup that appears when you complete or delete a task has been fortified. Even if the Flutter animation system gets confused, the popup is now strictly commanded to disappear exactly 4 seconds after appearing.

## How to Test

> [!IMPORTANT]
> **Reinstall Required:** Because I added deep system dependencies for notifications and permissions, you MUST do a full rebuild on your device.

Run the following command from your terminal to completely reinstall the app:
```bash
flutter clean
flutter pub get
flutter run
```

1. **Permissions Check:** When the app opens, ensure it asks for Notification and Exact Alarm permissions.
2. **Clear DB Test:** Open the side drawer and test the "Clear All Tasks" button.
3. **Alarm Test:** Create a new task with an alarm 6 minutes in the future.
4. **Pre-Alarm Test:** 1 minute later (5 minutes before the alarm), check your notification shade for the "starts in 5 minutes" warning.
5. **Snooze Test:** Let the alarm ring, tap "SNOOZE" for 5 minutes, and verify it stops and rings again 5 minutes later.
