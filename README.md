# Karaneeyaani

A flow-driven, premium Todo application built with Flutter and Firebase. Karaneeyaani goes beyond traditional, stressful task lists by grounding its core features in cognitive psychology and behavioral science to actively reduce procrastination and induce flow states.

## ✨ Features

- **The Daily Roadmap**: Eliminates decision fatigue by visually mapping your tasks for the day.
- **Deep Work Sanctuary**: A distraction-free, glassmorphic UI that locks you into a single task to prevent context-switching and induce a state of flow.
- **Cognitive Offloading**: Frictionless task creation (Title & Description) to get things out of your head quickly (Zeigarnik Effect).
- **Implementation Intentions**: End Dates and Smart Alarms force you to set concrete times for execution, drastically increasing completion rates.
- **Realtime Sync**: Powered by Firebase Cloud Firestore, your tasks instantly sync across Android, iOS, Web, Desktop, and MacOS.

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable version)
- A [Firebase Project](https://console.firebase.google.com/)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/AniruddhaMJois/karaneeyani.git
   cd karaneeyani
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Connect to Firebase:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   *(Follow the prompts to link the app to your Firebase project)*

4. Run the app:
   ```bash
   flutter run
   ```

## 🧠 The Science Behind the App

- **The Zeigarnik Effect**: Unfinished tasks create cognitive tension. This app is designed to capture everything instantly to offload that burden.
- **Implementation Intentions**: Planning *when* and *where* a task will be done increases success rates. The integrated alarm system ensures every task has an intention.
- **Ego Depletion**: The Deep Work Sanctuary hides everything except your current task, preserving your willpower from the exhaustion of context switching.

