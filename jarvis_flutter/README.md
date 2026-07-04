# JARVIS – Android (Flutter)

JARVIS – Just A Rather Very Intelligent System  
Zielgerät: **Honor MagicPad 4 | Android 16 | MagicOS 10**

---

## Funktionen

| Funktion | Status | Technik |
|---|---|---|
| 🧠 **Gehirn-Hologramm** | ✅ 60 FPS | `CustomPainter` (3200 Nodes, 3D-Projektion) |
| 🎤 **Sprachsteuerung** | ✅ Deutsch | `speech_to_text` + `flutter_tts` |
| 🤖 **KI-Chat** | ✅ OpenAI GPT | `http` + `.env` |
| 📋 **Aufgaben** | ✅ SQLite | `sqflite` |
| ⏰ **Erinnerungen** | ✅ SQLite | `sqflite` |
| 📱 **Apps öffnen** | ✅ Intents | `android_intent_plus` |
| 🖥 **Vollbild** | ✅ Immersive | `SystemChrome` |

---

## Build-Anleitung (APK)

### 1. Voraussetzungen

- **Flutter SDK** ≥ 3.22 (Installation: https://flutter.dev/docs/get-started/install)
- **Android Studio** oder **Android SDK** (API 34)
- **Java 17** (im Android Studio Bundle enthalten)
- Das Tablet **Honor MagicPad 4** via USB verbinden (Entwicklermodus + USB-Debugging aktivieren)

### 2. Setup

```bash
# Flutter installieren (falls nicht vorhanden)
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# SDK akzeptieren
flutter doctor --android-licenses

# Repo klonen
cd jarvis_flutter

# API-Key eintragen
echo "OPENAI_API_KEY=sk-..." > .env

# Dependencies holen
flutter pub get
```

### 3. Debug-Build (direkt auf dem Tablet testen)

```bash
# Tablet via USB anschließen und prüfen
flutter devices
# → Honor MagicPad 4 sollte in der Liste erscheinen

# Debug-Modus starten (Hot Reload möglich)
flutter run

# Oder: APK ohne Flutter-Debug-UI
flutter run --release
```

### 4. Release-APK bauen

```bash
# APK erzeugen
flutter build apk --release

# Output:
#   build/app/outputs/flutter-apk/app-release.apk

# ODER: Split-APK (kleiner, pro Architektur)
flutter build apk --release --split-per-abi

# Output:
#   build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
#   build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
#   build/app/outputs/flutter-apk/app-x86_64-release.apk
```

### 5. APK auf das Tablet installieren

```bash
# Direkt via adb
adb install build/app/outputs/flutter-apk/app-release.apk

# Oder: APK auf das Tablet kopieren und manuell öffnen
adb push build/app/outputs/flutter-apk/app-release.apk /sdcard/Download/
```

---

## Projektstruktur

```
jarvis_flutter/
├── lib/
│   ├── main.dart                     # Entry Point + Vollbild
│   ├── app.dart                      # MaterialApp + Theme
│   ├── core/                         # Services
│   │   ├── ai_service.dart           # OpenAI API
│   │   ├── database_service.dart     # SQLite (sqflite)
│   │   ├── voice_service.dart        # STT + TTS
│   │   └── app_launcher.dart         # Android Intents
│   ├── models/                       # Datenmodelle
│   │   ├── task.dart
│   │   ├── reminder.dart
│   │   └── chat_message.dart
│   ├── providers/                    # State Management
│   │   └── jarvis_provider.dart
│   ├── screens/                      # Bildschirme
│   │   └── home_screen.dart          # Tablet-Layout
│   └── widgets/                      # UI-Komponenten
│       ├── brain_hologram.dart       # Gehirn-Animation
│       ├── neon_container.dart       # Neonrahmen
│       ├── chat_panel.dart           # KI-Chat
│       ├── reminder_panel.dart       # Tasks + Reminders
│       ├── voice_button.dart         # Mikrofon-Button
│       └── status_bar.dart           # Systemstatus
├── android/                          # Android-Konfiguration
├── .env                              # OPENAI_API_KEY
├── pubspec.yaml
└── README.md
```

---

## Funktions-Mapping (Python → Flutter)

| Python (PyQt6) | Flutter (Dart) |
|---|---|
| `GLBrainWidget` (OpenGL) | `BrainHologram` (CustomPainter) |
| `NeonPanel` | `NeonContainer` |
| `MainWindow` | `HomeScreen` |
| `ai.ask_ai()` | `AiService.askAi()` |
| `DatabaseManager` | `DatabaseService` |
| `ReminderDB` | `DatabaseService` (combined) |
| `VoiceController` | `VoiceService` |
| `open_youtube()` etc. | `AppLauncher.openYouTube()` |
| `Assistant` | `JarvisProvider` |

---

## Anmerkungen für Honor MagicPad 4

- **Display**: 12.1" 2560×1600 – Die UI skaliert automatisch
- **Landscape-Modus**: Wird erzwungen für beste Hologramm-Darstellung
- **Stylus**: Funktioniert mit allen Touch-Interaktionen
- **Leistung**: Snapdragon 8 Gen 2 – 3200 Nodes bei 60 FPS sind garantiert
- **Mikrofon**: 4 Mikrofone – Sprachsteuerung funktioniert auch aus Distanz
- **Akkuoptimierung**: Falls die App im Hintergrund geschlossen wird, `adb shell dumpsys deviceidle whitelist +com.jarvis.app` ausführen

---

## Lizenz

MIT
