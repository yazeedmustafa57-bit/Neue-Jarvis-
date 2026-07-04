#!/bin/bash
# JARVIS APK Builder
# Build-Skript für Linux/macOS/Windows (WSL)
# 
# Nutzung:
#   chmod +x build_apk.sh
#   ./build_apk.sh

set -e

echo "╔════════════════════════════════════════╗"
echo "║     JARVIS - APK Builder              ║"
echo "╚════════════════════════════════════════╝"

# ── Prüfen ob Flutter installiert ──────────────────────────────────
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter SDK nicht gefunden."
    echo ""
    echo "Installiere es manuell:"
    echo "  https://docs.flutter.dev/get-started/install"
    echo ""
    echo "Oder nutze den Online-Build via GitHub Actions:"
    echo "  1. Gehe zu https://github.com/yazeedmustafa57-bit/Neue-Jarvis-/actions"
    echo "  2. Klicke 'Build JARVIS APK' → 'Run workflow'"
    echo "  3. Lade die APK aus den Artifacts herunter"
    echo ""
    exit 1
fi

echo "✅ Flutter SDK: $(flutter --version | head -1)"

# ── Directory ───────────────────────────────────────────────────────
cd "$(dirname "$0")/jarvis_flutter"

# ── API Key ──────────────────────────────────────────────────────────
if [ ! -f .env ]; then
    echo ""
    echo "🔑 OpenAI API-Key eingeben (leer = Platzhalter):"
    read -r key
    if [ -z "$key" ]; then
        echo "OPENAI_API_KEY=sk-dein-openai-api-key-hier" > .env
    else
        echo "OPENAI_API_KEY=$key" > .env
    fi
    echo "✅ .env erstellt"
fi

# ── Dependencies ────────────────────────────────────────────────────
echo ""
echo "📦 Dependencies werden geladen …"
flutter pub get
echo "✅ flutter pub get"

# ── Android-Lizenzen akzeptieren ────────────────────────────────────
echo ""
echo "📜 Android-Lizenzen …"
flutter doctor --android-licenses 2>/dev/null || true

# ── APK bauen ────────────────────────────────────────────────────────
echo ""
echo "🔨 Baue Release APK …"
flutter build apk --release
echo ""
echo "✅ APK erstellt!"
echo ""
echo "📁 build/app/outputs/flutter-apk/app-release.apk"
echo ""

# ── Auf dem Tablet installieren ──────────────────────────────────────
if command -v adb &> /dev/null; then
    echo "📱 Tablet via ADB suchen …"
    if adb devices | grep -q "device$"; then
        echo "   Tablet gefunden! Installiere …"
        adb install -r build/app/outputs/flutter-apk/app-release.apk
        echo "✅ Installation abgeschlossen!"
    else
        echo "⚠️  Kein Tablet via ADB verbunden."
        echo "   APK manuell installieren:"
        echo "   adb install build/app/outputs/flutter-apk/app-release.apk"
    fi
fi

echo ""
echo "╔════════════════════════════════════════╗"
echo "║  🎉  JARVIS ist bereit!               ║"
echo "╚════════════════════════════════════════╝"
