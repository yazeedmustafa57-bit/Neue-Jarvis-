import 'dart:async';
import 'package:flutter/foundation.dart';
import 'accessibility_service.dart';
import 'app_launcher.dart';

/// Result of a task execution.
class TaskResult {
  final bool success;
  final String message;
  final String? details;
  const TaskResult(this.success, this.message, {this.details});
}

/// Complex multi-step task executor for autonomous assistance.
/// Uses Accessibility Service + Android Intents to perform tasks.
class TaskExecutor {
  /// Known app package names for common apps.
  static const Map<String, String> appPackages = {
    'whatsapp': 'com.whatsapp',
    'telegram': 'org.telegram.messenger',
    'youtube': 'com.google.android.youtube',
    'chrome': 'com.android.chrome',
    'gmail': 'com.google.android.gm',
    'maps': 'com.google.android.apps.maps',
    'settings': 'com.android.settings',
    'clock': 'com.google.android.deskclock',
    'calendar': 'com.google.android.calendar',
    'calculator': 'com.google.android.calculator',
    'files': 'com.android.documentsui',
    'photos': 'com.google.android.apps.photos',
    'spotify': 'com.spotify.music',
    'discord': 'com.discord',
    'twitter': 'com.twitter.android',
    'instagram': 'com.instagram.android',
    'whatsapp_business': 'com.whatsapp.w4b',
    'phone': 'com.google.android.dialer',
    'contacts': 'com.google.android.contacts',
    'messenger': 'com.facebook.orca',
  };

  // ─── Task Execution ──────────────────────────────────────────────────

  /// Parse and execute a voice/text command.
  /// Returns a TaskResult describing what happened.
  static Future<TaskResult> execute(String command) async {
    final cmd = command.toLowerCase().trim();

    // Navigation / system
    if (cmd.contains('zurück') || cmd.contains('back')) {
      await AccessibilityService.goBack();
      return TaskResult(true, '⏪ Zurück navigiert.');
    }
    if (cmd.contains('startseite') || cmd == 'home') {
      await AccessibilityService.goHome();
      return TaskResult(true, '🏠 Startseite geöffnet.');
    }
    if (cmd.contains('benachrichtigung') || cmd.contains('notification')) {
      await AccessibilityService.openNotifications();
      return TaskResult(true, '🔔 Benachrichtigungen geöffnet.');
    }
    if (cmd.contains('schnelleinstellungen') || cmd.contains('quick settings')) {
      await AccessibilityService.openQuickSettings();
      return TaskResult(true, '⚡ Schnelleinstellungen geöffnet.');
    }

    // App launcher
    for (final entry in appPackages.entries) {
      if (cmd.contains('öffne ${entry.key}') ||
          cmd.contains('starte ${entry.key}') ||
          cmd == entry.key) {
        final opened = await AccessibilityService.openApp(entry.value);
        if (opened) {
          return TaskResult(true, '✅ ${entry.key} geöffnet.');
        }
        // Fallback to intent
        await AppLauncher.execute(entry.key);
        return TaskResult(true, '✅ ${entry.key} geöffnet (Intent).');
      }
    }

    // Standard app launcher commands
    if (cmd.contains('youtube') || cmd.contains('google')) {
      if (cmd.contains('youtube')) {
        await AppLauncher.execute('youtube');
        return TaskResult(true, '▶️ YouTube geöffnet.');
      }
      if (cmd.contains('google')) {
        await AppLauncher.execute('google');
        return TaskResult(true, '🌐 Google geöffnet.');
      }
    }

    // ─── Complex Multi-Step Tasks ────────────────────────────────────

    // Send WhatsApp/Telegram message
    if (cmd.contains('nachricht') || cmd.contains('send') || cmd.contains('schreibe')) {
      return _handleSendMessage(cmd);
    }

    // Set alarm
    if ((cmd.contains('wecker') || cmd.contains('alarm')) &&
        cmd.contains('uhr')) {
      return _handleSetAlarm(cmd);
    }

    // Timer
    if (cmd.contains('timer') || cmd.contains('stoppuhr')) {
      return _handleTimer(cmd);
    }

    // Search
    if (cmd.contains('suche') || cmd.contains('search')) {
      return _handleSearch(cmd);
    }

    // Open app → perform action
    if (cmd.contains('mach') && cmd.contains('auf')) {
      return _handleOpenAndDo(cmd);
    }

    // Device info
    if (cmd.contains('akku') || cmd.contains('battery') || cmd.contains('status')) {
      final battery = await AccessibilityService.getBatteryLevel();
      if (battery >= 0) {
        return TaskResult(true, '🔋 Akku: $battery%');
      }
      return TaskResult(true, '🔋 Akku-Stand konnte nicht ermittelt werden.');
    }

    // Unknown command
    return TaskResult(false, '❌ Unbekannter Befehl: "$command"');
  }

  // ─── Complex Task: Send Message ──────────────────────────────────────
  static Future<TaskResult> _handleSendMessage(String cmd) async {
    // Pattern: "send [contact] message [text]"
    String? app = 'whatsapp';
    String? contact;
    String? message;

    if (cmd.contains('telegram')) app = 'telegram';
    if (cmd.contains('whatsapp')) app = 'whatsapp';
    if (cmd.contains('sms') || cmd.contains('nachricht')) app = 'messages';

    // Extract contact: anything between "an " / "to " and " "
    final contactMatch = RegExp(r'(?:an |to |für |an\s+)([\w\s]+?)(?: (?:die |eine |dass |message |text))').firstMatch(cmd);
    if (contactMatch != null) {
      contact = contactMatch.group(1)?.trim();
    }

    // Extract message: anything after "message" or "text" or "dass"
    final msgMatch = RegExp(r'(?:message |text |sagen |dass |schreiben\s*:?\s*)([\w\s]+)$').firstMatch(cmd);
    if (msgMatch != null) {
      message = msgMatch.group(1)?.trim();
    }

    if (contact == null && message == null) {
      return TaskResult(false, '❌ Befehl nicht erkannt. Beispiel: "Sende WhatsApp an Mama: Hallo"');
    }

    // Open the app via package
    final pkg = appPackages[app];
    if (pkg == null) {
      return TaskResult(false, '❌ App $app nicht gefunden.');
    }

    await AccessibilityService.openApp(pkg);
    await Future.delayed(const Duration(milliseconds: 1500));

    if (contact != null) {
      // Try to click in the search/contact field
      await AccessibilityService.clickByText(contact);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (message != null) {
      // Type the message
      await AccessibilityService.pasteText(message);
      await Future.delayed(const Duration(milliseconds: 300));
      // Click send (usually a button with content description "send" or icon)
      await AccessibilityService.clickByContentDescription('send');
      await Future.delayed(const Duration(milliseconds: 200));
    }

    return TaskResult(true, '✅ Nachricht gesendet.');
  }

  // ─── Complex Task: Set Alarm ────────────────────────────────────────
  static Future<TaskResult> _handleSetAlarm(String cmd) async {
    // Pattern: "set alarm at [time]" or "wecker um [zeit]"
    final timeMatch = RegExp(r'(?:um |at |für |)(\d{1,2})[:.]?(\d{2})?\s*(?:uhr)?').firstMatch(cmd);
    String? timeStr;
    if (timeMatch != null) {
      final h = timeMatch.group(1) ?? '7';
      final m = timeMatch.group(2) ?? '00';
      timeStr = '$h:$m';
    }

    await AccessibilityService.openApp(appPackages['clock']!);
    await Future.delayed(const Duration(milliseconds: 1500));

    // Click "Alarm" tab or button
    await AccessibilityService.clickByText('Alarm');
    await Future.delayed(const Duration(milliseconds: 500));

    // Click add alarm button
    await AccessibilityService.clickByContentDescription('add alarm');
    await Future.delayed(const Duration(milliseconds: 500));

    if (timeStr != null) {
      await AccessibilityService.clickByText(timeStr);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    return TaskResult(true, '⏰ Wecker gestellt${timeStr != null ? ' um $timeStr' : ''}.');
  }

  // ─── Complex Task: Timer ────────────────────────────────────────────
  static Future<TaskResult> _handleTimer(String cmd) async {
    final minuteMatch = RegExp(r'(\d+)\s*(minuten?|minute|min)').firstMatch(cmd);
    final secondMatch = RegExp(r'(\d+)\s*(sekunden?|sekunde|sec)').firstMatch(cmd);
    int totalSec = 0;
    if (minuteMatch != null) totalSec += int.parse(minuteMatch.group(1)!) * 60;
    if (secondMatch != null) totalSec += int.parse(secondMatch.group(1)!);

    await AccessibilityService.openApp(appPackages['clock']!);
    await Future.delayed(const Duration(milliseconds: 1500));

    await AccessibilityService.clickByText('Timer');
    await Future.delayed(const Duration(milliseconds: 500));

    if (totalSec > 0) {
      // Type the timer duration
      final min = (totalSec ~/ 60).toString();
      final sec = (totalSec % 60).toString();
      await AccessibilityService.typeText('${min.padLeft(2, '0')}${sec.padLeft(2, '0')}');
      await Future.delayed(const Duration(milliseconds: 300));
      await AccessibilityService.clickByText('Start');
    }

    return TaskResult(true, '⏱️ Timer gestellt: ${totalSec ~/ 60}m ${totalSec % 60}s');
  }

  // ─── Complex Task: Search ──────────────────────────────────────────
  static Future<TaskResult> _handleSearch(String cmd) async {
    // Pattern: "suche [query] auf [app]" or "search [query] on [app]"
    String? query;
    String? platform;

    // Extract search query
    final queryMatch = RegExp(r'(?:suche |search |finde |nach\s+)([\w\s]+?)(?: (?:auf |in |bei |on )|$)').firstMatch(cmd);
    if (queryMatch != null) {
      query = queryMatch.group(1)?.trim();
    }

    if (cmd.contains('youtube')) platform = 'youtube';
    if (cmd.contains('google') || cmd.contains('web')) platform = 'google';

    if (query == null) {
      return TaskResult(false, '❌ Suchbegriff nicht erkannt.');
    }

    if (platform == 'youtube') {
      await AppLauncher.execute('youtube');
      await Future.delayed(const Duration(milliseconds: 2000));
      await AccessibilityService.clickByContentDescription('search');
      await Future.delayed(const Duration(milliseconds: 500));
      await AccessibilityService.pasteText(query);
      await Future.delayed(const Duration(milliseconds: 300));
      // Press search
      await AccessibilityService.goBack();
      return TaskResult(true, '🔍 Suche "$query" auf YouTube.');
    }

    // Default: Google search
    await AppLauncher.execute('google');
    await Future.delayed(const Duration(milliseconds: 1500));
    await AccessibilityService.pasteText(query);
    await Future.delayed(const Duration(milliseconds: 300));

    return TaskResult(true, '🔍 Suche "$query" im Web.');
  }

  // ─── Complex Task: Open + Do ────────────────────────────────────────
  static Future<TaskResult> _handleOpenAndDo(String cmd) async {
    // Pattern: "mach [app] auf und [action]"
    for (final entry in appPackages.entries) {
      if (cmd.contains(entry.key)) {
        await AccessibilityService.openApp(entry.value);
        await Future.delayed(const Duration(milliseconds: 1500));
        return TaskResult(true, '✅ ${entry.key} geöffnet und bereit.');
      }
    }
    return TaskResult(false, '❌ App nicht gefunden.');
  }
}
