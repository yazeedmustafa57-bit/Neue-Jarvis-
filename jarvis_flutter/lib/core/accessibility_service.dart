import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Flutter interface for the JARVIS Android Accessibility Service.
/// Allows system-wide UI automation: clicking, typing, gestures, etc.
class AccessibilityService {
  static const MethodChannel _mainChannel = MethodChannel('com.jarvis.app/main');
  static const MethodChannel _accessChannel = MethodChannel('com.jarvis.app/accessibility');

  // ── Status ──────────────────────────────────────────────────────────

  /// Check if the accessibility service is enabled in system settings.
  static Future<bool> isServiceEnabled() async {
    try {
      final result = await _mainChannel.invokeMethod<bool>('isAccessibilityServiceEnabled');
      return result ?? false;
    } catch (e) {
      debugPrint('isServiceEnabled error: $e');
      return false;
    }
  }

  /// Open Android accessibility settings so the user can enable JARVIS.
  static Future<void> requestPermission() async {
    try {
      await _mainChannel.invokeMethod('requestAccessibilityPermission');
    } catch (e) {
      debugPrint('requestPermission error: $e');
    }
  }

  // ─── Click Actions ──────────────────────────────────────────────────

  /// Click a UI element by its visible text.
  static Future<bool> clickByText(String text) async {
    try {
      final result = await _accessChannel.invokeMethod<Map>('clickByText', {'text': text});
      return result?['success'] == true;
    } catch (e) {
      debugPrint('clickByText error: $e');
      return false;
    }
  }

  /// Click a UI element by its view ID.
  static Future<bool> clickById(String id) async {
    try {
      final result = await _accessChannel.invokeMethod<Map>('clickById', {'id': id});
      return result?['success'] == true;
    } catch (e) {
      debugPrint('clickById error: $e');
      return false;
    }
  }

  /// Click a UI element by its content description.
  static Future<bool> clickByContentDescription(String description) async {
    try {
      final result = await _accessChannel.invokeMethod<Map>('clickByContentDescription', {'description': description});
      return result?['success'] == true;
    } catch (e) {
      debugPrint('clickByContentDescription error: $e');
      return false;
    }
  }

  // ─── Text Input ─────────────────────────────────────────────────────

  /// Type text directly into the currently focused input field.
  static Future<bool> typeText(String text) async {
    try {
      final result = await _accessChannel.invokeMethod<Map>('typeText', {'text': text});
      return result?['success'] == true;
    } catch (e) {
      debugPrint('typeText error: $e');
      return false;
    }
  }

  /// Copy text to clipboard and paste into the focused field.
  static Future<bool> pasteText(String text) async {
    try {
      final result = await _accessChannel.invokeMethod<Map>('pasteText', {'text': text});
      return result?['success'] == true;
    } catch (e) {
      debugPrint('pasteText error: $e');
      return false;
    }
  }

  // ─── Global Actions ─────────────────────────────────────────────────

  /// Perform system-level actions: back, home, recents, notifications, quick_settings
  static Future<bool> performAction(String action) async {
    try {
      final result = await _accessChannel.invokeMethod<Map>('performGlobalAction', {'action': action});
      return result?['success'] == true;
    } catch (e) {
      debugPrint('performAction error: $e');
      return false;
    }
  }

  static Future<bool> goBack() => performAction('back');
  static Future<bool> goHome() => performAction('home');
  static Future<bool> openRecents() => performAction('recents');
  static Future<bool> openNotifications() => performAction('notifications');
  static Future<bool> openQuickSettings() => performAction('quick_settings');

  // ─── Screen Content ─────────────────────────────────────────────────

  /// Get all visible text from the current screen.
  static Future<String> getScreenContent() async {
    try {
      final result = await _accessChannel.invokeMethod<Map>('getScreenContent');
      return result?['text'] as String? ?? '';
    } catch (e) {
      debugPrint('getScreenContent error: $e');
      return '';
    }
  }

  /// Get text from the currently focused input field.
  static Future<String> getFocusedText() async {
    try {
      final result = await _accessChannel.invokeMethod<Map>('getFocusedText');
      return result?['text'] as String? ?? '';
    } catch (e) {
      debugPrint('getFocusedText error: $e');
      return '';
    }
  }

  // ─── Gestures ───────────────────────────────────────────────────────

  /// Tap at specific screen coordinates.
  static Future<bool> tapAt(double x, double y) async {
    try {
      final result = await _accessChannel.invokeMethod<Map>('tapAt', {'x': x, 'y': y});
      return result?['success'] == true;
    } catch (e) {
      debugPrint('tapAt error: $e');
      return false;
    }
  }

  /// Perform a swipe gesture.
  static Future<bool> swipe(double x1, double y1, double x2, double y2) async {
    try {
      final result = await _accessChannel.invokeMethod<Map>('swipe', {
        'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2,
      });
      return result?['success'] == true;
    } catch (e) {
      debugPrint('swipe error: $e');
      return false;
    }
  }

  // ─── App Launch ─────────────────────────────────────────────────────

  /// Open an app by its Android package name.
  static Future<bool> openApp(String packageName) async {
    try {
      final result = await _accessChannel.invokeMethod<Map>('openApp', {'packageName': packageName});
      return result?['success'] == true;
    } catch (e) {
      debugPrint('openApp error: $e');
      return false;
    }
  }

  // ─── Device Info ────────────────────────────────────────────────────

  /// Get the current battery level (0-100).
  static Future<int> getBatteryLevel() async {
    try {
      final result = await _mainChannel.invokeMethod<int>('getBatteryLevel');
      return result ?? -1;
    } catch (e) {
      debugPrint('getBatteryLevel error: $e');
      return -1;
    }
  }
}
