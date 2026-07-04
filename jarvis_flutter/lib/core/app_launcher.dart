import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';

class AppLauncher {
  static Future<String> openYouTube() async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'https://www.youtube.com',
      );
      await intent.launch();
      return 'YouTube geöffnet.';
    } catch (e) {
      debugPrint('openYouTube error: $e');
      return 'Fehler: $e';
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
        data: 'https://open.spotify.com',
        package: 'com.spotify.music',
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
      case 'notepad':
        return 'Notepad ist auf Android nicht verfügbar.';
      default:
        return 'Unbekannter Befehl: $action';
    }
  }
}
