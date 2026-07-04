import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';

/// Enhanced app launcher with deep linking and system control intents.
class AppLauncher {
  // ─── App Launch by Package ──────────────────────────────────────────
  static Future<String> openByPackage(String packageName) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: packageName,
      );
      await intent.launch();
      return '$packageName gestartet.';
    } catch (e) {
      debugPrint('openByPackage error: $e');
      return 'Fehler beim Öffnen von $packageName: $e';
    }
  }

  // ─── Specific App Launches ──────────────────────────────────────────

  static Future<String> openYouTube() async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'https://www.youtube.com',
        package: 'com.google.android.youtube',
      );
      await intent.launch();
      return 'YouTube geöffnet.';
    } catch (_) {
      // Fallback: web
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: 'https://www.youtube.com',
        );
        await intent.launch();
        return 'YouTube (Web) geöffnet.';
      } catch (e) {
        return 'Fehler: $e';
      }
    }
  }

  static Future<String> openGoogle() async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'https://www.google.com',
      );
      await intent.launch();
      return 'Google geöffnet.';
    } catch (e) {
      debugPrint('openGoogle error: $e');
      return 'Fehler: $e';
    }
  }

  static Future<String> openChrome() async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'https://www.google.com',
        package: 'com.android.chrome',
      );
      await intent.launch();
      return 'Chrome gestartet.';
    } catch (_) {
      return openGoogle();
    }
  }

  static Future<String> openDiscord() async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'https://discord.com/app',
      );
      await intent.launch();
      return 'Discord geöffnet.';
    } catch (e) {
      debugPrint('openDiscord error: $e');
      return 'Fehler: $e';
    }
  }

  static Future<String> openSpotify() async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        package: 'com.spotify.music',
        data: 'https://open.spotify.com',
      );
      await intent.launch();
      return 'Spotify geöffnet.';
    } catch (_) {
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: 'https://open.spotify.com',
        );
        await intent.launch();
        return 'Spotify Web geöffnet.';
      } catch (e) {
        return 'Fehler: $e';
      }
    }
  }

  static Future<String> openWhatsApp() async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        package: 'com.whatsapp',
        data: 'https://wa.me/',
      );
      await intent.launch();
      return 'WhatsApp geöffnet.';
    } catch (e) {
      return 'Fehler: $e';
    }
  }

  static Future<String> openTelegram() async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        package: 'org.telegram.messenger',
        data: 'https://t.me/',
      );
      await intent.launch();
      return 'Telegram geöffnet.';
    } catch (e) {
      return 'Fehler: $e';
    }
  }

  static Future<String> openSettings() async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.SETTINGS',
      );
      await intent.launch();
      return 'Einstellungen geöffnet.';
    } catch (e) {
      return 'Fehler: $e';
    }
  }

  static Future<String> openWifiSettings() async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.WIFI_SETTINGS',
      );
      await intent.launch();
      return 'WLAN-Einstellungen geöffnet.';
    } catch (e) {
      return 'Fehler: $e';
    }
  }

  static Future<String> openBluetoothSettings() async {
    try {
      final intent = AndroidIntent(
        action: "android.settings.BLUETOOTH_SETTINGS",
      );
      await intent.launch();
      return 'Bluetooth-Einstellungen geöffnet.';
    } catch (e) {
      return 'Fehler: $e';
    }
  }

  // ─── Router ─────────────────────────────────────────────────────────

  static Future<String> execute(String action) async {
    switch (action) {
      case 'youtube':
        return openYouTube();
      case 'google':
        return openGoogle();
      case 'chrome':
        return openChrome();
      case 'discord':
        return openDiscord();
      case 'spotify':
        return openSpotify();
      case 'whatsapp':
        return openWhatsApp();
      case 'telegram':
        return openTelegram();
      case 'settings':
        return openSettings();
      case 'wifi':
        return openWifiSettings();
      case 'bluetooth':
        return openBluetoothSettings();
      case 'notepad':
        return 'Notepad ist auf Android nicht verfügbar.';
      default:
        return 'Unbekannter Befehl: $action';
    }
  }
}
