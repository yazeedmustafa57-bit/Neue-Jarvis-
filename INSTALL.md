# JARVIS APK installieren

## 🚀 Weg 1: GitHub Actions (empfohlen – kein Setup nötig)

Die APK wird automatisch in der GitHub-Cloud gebaut.

1. **Gehe zu** https://github.com/yazeedmustafa57-bit/Neue-Jarvis-/actions
2. Klicke links auf **"Build JARVIS APK"**
3. Klicke rechts auf **"Run workflow"** → grünen Button drücken
4. Warte ~5 Minuten
5. Lade die APK herunter:
   - Klicke auf den abgeschlossenen Workflow-Run
   - Scrolle runter zu **"Artifacts"**
   - Lade **jarvis-release-apk.zip** herunter
6. Entpacken und APK aufs Tablet:
   ```
   adb install app-release.apk
   ```
   Oder: APK aufs Tablet kopieren und dort öffnen.

### GitHub Secrets (optional – für OpenAI API-Key)
Damit der KI-Chat funktioniert, hinterlege deinen API-Key:

1. https://github.com/yazeedmustafa57-bit/Neue-Jarvis-/settings/secrets/actions
2. "New repository secret"
3. Name: `OPENAI_API_KEY`
4. Value: `sk-proj-...` (dein Key)

---

## 📱 Weg 2: Lokal bauen (Windows/macOS/Linux x86_64)

**Voraussetzung:** Flutter SDK installiert
```
git clone https://github.com/yazeedmustafa57-bit/Neue-Jarvis-.git
cd Neue-Jarvis-/jarvis_flutter

# API-Key eintragen
echo "OPENAI_API_KEY=sk-..." > .env

# APK bauen
flutter pub get
flutter build apk --release

# Installieren
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## ▶️ Start auf dem Honor MagicPad 4

1. APK installieren
2. App starten → automatischer Vollbildmodus
3. Mikrofon-Button antippen für Sprachsteuerung
4. "Öffne YouTube", "Öffne Google", etc. sprechen
5. KI-Chat: Text eingeben und auf ⚡ tippen
6. Aufgaben & Erinnerungen via Tabs verwalten
