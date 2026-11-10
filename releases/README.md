# Karaneeyaani - Installation & Setup Guides

This directory contains pre-built releases for **Android**, **Windows**, and **Linux**. Follow the quick, step-by-step guides below for your operating system.

---

## 📱 1. Android Installation (`.apk`)

**File**: `karaneeyaani-android.apk`  
**Compatibility**: Android 7.0 (API 24) or newer.

### Easy Step-by-Step Instructions:
1. **Download the APK**: Download [`karaneeyaani-android.apk`](karaneeyaani-android.apk) directly onto your Android device or transfer it via USB/Google Drive.
2. **Open the File**: Locate the downloaded APK in your device's **Files** or **Downloads** folder and tap on it.
3. **Allow Installation from Unknown Sources**:
   - If prompted by Android (*"For your security, your phone is not allowed to install unknown apps from this source"*), tap **Settings**.
   - Toggle **Allow from this source** to ON.
4. **Complete Installation**:
   - Tap **Install** and wait for the process to finish.
   - Tap **Open** to launch Karaneeyaani.
5. **Permissions**:
   - Grant notification and alarm permissions when prompted so time-boxed routines and reminders ring reliably.

---

## 🪟 2. Windows Installer (`.exe`)

**File**: `Karaneeyaani-Setup.exe`  
**Compatibility**: Windows 10 / Windows 11 (64-bit).

### Easy Step-by-Step Instructions:
1. **Download the Installer**: Download [`Karaneeyaani-Setup.exe`](Karaneeyaani-Setup.exe).
2. **Launch Installer**: Double-click `Karaneeyaani-Setup.exe`.
3. **Windows SmartScreen Prompt** (if shown):
   - Click **More info**.
   - Click **Run anyway**.
4. **Follow Setup Wizard**:
   - Select installation destination (default: `C:\Program Files\Karaneeyaani`).
   - Check the box to create a **Desktop Shortcut** (recommended).
   - Click **Install**, then click **Finish**.
5. **Launch**: Start Karaneeyaani from your Desktop shortcut or Start Menu.

---

## 🪟 3. Windows Portable Version (`.zip`)

**File**: `Karaneeyaani-Windows-Portable.zip`  
**Compatibility**: Windows 10 / Windows 11 (64-bit, No Admin Rights Required).

### Easy Step-by-Step Instructions:
1. **Download the Archive**: Download [`Karaneeyaani-Windows-Portable.zip`](Karaneeyaani-Windows-Portable.zip).
2. **Extract Files**:
   - Right-click the downloaded `.zip` file and select **Extract All...**.
   - Choose a folder (e.g. `Downloads\Karaneeyaani` or `Documents\Karaneeyaani`) and click **Extract**.
3. **Run Application**:
   - Open the extracted folder and double-click `karaneeyaani_windows.exe`.
   - No installation or admin permissions required.

---

## 🐧 4. Linux Desktop (`.tar.gz`)

**File**: `karaneeyaani-linux-x64.tar.gz`  
**Compatibility**: Ubuntu, Debian, Fedora, Arch, and GTK+ 3.0 supported distributions (x86_64).

### Easy Step-by-Step Instructions:

#### Option A: Using the Graphical File Manager (GUI)
1. Download [`karaneeyaani-linux-x64.tar.gz`](karaneeyaani-linux-x64.tar.gz).
2. Right-click the `.tar.gz` file and select **Extract Here**.
3. Open the extracted folder.
4. Double-click the executable `karaneeyaani_linux` (or right-click -> **Run as Program**).

#### Option B: Using the Terminal (CLI)
1. Open your terminal in the directory where the file was downloaded:
   ```bash
   tar -xzf karaneeyaani-linux-x64.tar.gz
   cd karaneeyaani_linux/
   chmod +x karaneeyaani_linux
   ./karaneeyaani_linux
   ```

> **Note for Minimal Linux Distros**: Ensure standard GTK 3 libraries are installed:
> - **Ubuntu/Debian**: `sudo apt install libgtk-3-0 liblzma5`
> - **Fedora**: `sudo dnf install gtk3 xz-libs`
> - **Arch Linux**: `sudo pacman -S gtk3 xz`
