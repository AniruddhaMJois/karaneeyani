# Karaneeyaani

A flow-driven, premium Todo application built with Flutter and Firebase. Karaneeyaani goes beyond traditional, stressful task lists by grounding its core features in cognitive psychology, behavioral science, and responsive architecture to actively reduce procrastination and induce flow states.

## ✨ Features

- **Responsive Architecture**: Fully adaptive layout that shape-shifts between a single-column mobile interface and a multi-column, permanent-sidebar desktop experience.
- **Thematic Engine**: Built-in dynamic theming with psychologically brilliant colors designed to trigger dopamine and alert flow states (e.g., Focus State with Deep Obsidian and Electric Blue).
- **Authentication & Security**: Secure user accounts with Firebase Auth and strict Firestore security rules isolating each user's data.
- **Cognitive Offloading**: Frictionless task creation (Title & Description) to get things out of your head quickly (Zeigarnik Effect).
- **Implementation Intentions**: End Dates and Offline Smart Alarms force you to set concrete times for execution, drastically increasing completion rates—even when your phone has no internet connection.
- **The Daily Roadmap**: Eliminates decision fatigue by visually mapping your tasks for the day.
- **5-Day Recycle Bin**: Soft-delete feature keeps your deleted tasks safely in the bin for 5 days before permanently erasing them.

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
- **Color Psychology**: The "Focus State" theme utilizes high-contrast neon elements against pure blacks to maintain alertness and simulate a high-end, premium deep work environment.

