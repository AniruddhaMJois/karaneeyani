<div align="center">
  <img src="assets/icon.png" alt="Karaneeyaani Logo" width="150" height="150" />
  <h1>Karaneeyaani</h1>
  
  <p><b>A flow-driven, premium task management ecosystem built with Flutter and Firebase.</b></p>

  <p>
    <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter" />
    <img src="https://img.shields.io/badge/firebase-%23039BE5.svg?style=for-the-badge&logo=firebase" alt="Firebase" />
    <img src="https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  </p>

  <p>
    <em>Karaneeyaani goes beyond traditional, stressful task lists. By grounding its core features in cognitive psychology, behavioral science, and responsive architecture, it actively reduces procrastination and induces flow states.</em>
  </p>
</div>

<br />

## ✨ Key Features

### 🎨 Premium Aesthetics & UI
- **Responsive Architecture**: Fully adaptive layout that shape-shifts between a single-column mobile interface and a multi-column, permanent-sidebar desktop experience.
- **Thematic Engine**: Built-in dynamic theming with psychologically brilliant colors designed to trigger dopamine and alert flow states. Switch between modes instantly from the sidebar menu.
- **High-Contrast Glassmorphism**: Beautiful task cards with prominent background tints, glowing drop shadows, and distinct pill-shaped date/time badges that jump out against deep dark backgrounds.

### 🧠 Cognitive Task Management
- **Cognitive Offloading**: Frictionless task creation (Title & Description) to get things out of your head quickly, leveraging the *Zeigarnik Effect*.
- **Implementation Intentions**: End Dates and Offline Smart Alarms force you to set concrete times for execution, drastically increasing completion rates. 
- **Calendar Sorted View**: A dedicated secondary dashboard to view all tasks logically sorted chronologically by their deadlines.

### ⚡ Offline-First & Resilient
- **Zero-Lag Architecture**: Instantaneous local ID generation guarantees zero UI freezing or lag when creating tasks during network drops. The app fires and forgets, syncing seamlessly in the background when your connection stabilizes.
- **Smart Notification Ecosystem**: Wake-lock alarms trigger on time even when the screen is off or the app is closed. Dismissing an alarm instantly completes the task in the database, while displaying motivational quotes to drive action.

### 🔒 Security & Data Integrity
- **5-Day Recycle Bin**: Soft-delete feature keeps your deleted tasks safely in the bin for 5 days before permanently erasing them.
- **Authentication & Security**: Secure user accounts with Firebase Auth and strict Firestore security rules isolating each user's data.

---

## 🚀 Getting Started

### Prerequisites
Before you begin, ensure you have the following installed:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable version)
- A [Firebase Project](https://console.firebase.google.com/) configured for Android/iOS

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/AniruddhaMJois/karaneeyani.git
   cd karaneeyani
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Connect to Firebase:**
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   *(Follow the prompts to link the app to your specific Firebase project)*

4. **Run the app:**
   ```bash
   flutter run
   ```

---

## 🔬 The Science Behind the App

> **The Zeigarnik Effect**: Unfinished tasks create cognitive tension. This app is designed to capture everything instantly to offload that burden.

> **Implementation Intentions**: Planning *when* and *where* a task will be done significantly increases success rates. The integrated smart alarm system ensures every task has a concrete intention.

> **Color Psychology**: The "Focus State" theme utilizes high-contrast neon elements against pure blacks to maintain alertness and simulate a high-end, premium deep-work environment.

---

<div align="center">
  <p>Built with ❤️ for peak productivity.</p>
</div>
