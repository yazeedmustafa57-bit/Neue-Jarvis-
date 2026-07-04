import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';

enum VoiceState { idle, listening, speaking, error, noPermission }

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _isListening = false;
  bool _ttsReady = false;

  VoiceState _state = VoiceState.idle;
  VoiceState get state => _state;

  final ValueNotifier<VoiceState> stateNotifier = ValueNotifier(VoiceState.idle);

  // Callbacks
  void Function(String command)? onCommand;
  void Function(String error)? onError;
  void Function(String text)? onResult;
  void Function(String complexCommand)? onComplexCommand;

  // Simple direct commands
  static const Map<String, String> directCommands = {
    'öffne youtube': 'youtube',
    'öffne google': 'google',
    'öffne chrome': 'chrome',
    'öffne discord': 'discord',
    'öffne spotify': 'spotify',
    'öffne notepad': 'notepad',
    'öffne editor': 'notepad',
    'öffne whatsapp': 'whatsapp',
    'öffne telegram': 'telegram',
    'öffne einstellungen': 'settings',
    'öffne wifi': 'wifi',
    'öffne bluetooth': 'bluetooth',
    'beende jarvis': 'shutdown',
    'beenden': 'shutdown',
    'zurück': 'back',
    'startseite': 'home',
    'benachrichtigungen': 'notifications',
  };

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _initialized = await _speech.initialize(
        onError: (error) {
          debugPrint('Speech error: $error');
          _state = VoiceState.error;
          stateNotifier.value = _state;
          onError?.call('Spracherkennungsfehler: ${error.errorMsg}');
        },
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'notListening' || status == 'done') {
            _isListening = false;
            if (_state == VoiceState.listening) {
              _state = VoiceState.idle;
              stateNotifier.value = _state;
            }
          }
        },
      );

      // Initialize TTS
      try {
        await _tts.setLanguage('de-DE');
        await _tts.setSpeechRate(0.45);
        await _tts.setVolume(0.9);
        await _tts.setPitch(1.0);
        _ttsReady = true;
        _tts.setCompletionHandler(() {
          if (_state == VoiceState.speaking) {
            _state = VoiceState.idle;
            stateNotifier.value = _state;
          }
        });
      } catch (e) {
        debugPrint('TTS init warning: $e');
        _ttsReady = false;
      }

      if (!_initialized) {
        _state = VoiceState.noPermission;
        stateNotifier.value = _state;
        onError?.call('Keine Mikrofonberechtigung.');
      }
    } catch (e) {
      debugPrint('Voice init error: $e');
      _state = VoiceState.error;
      stateNotifier.value = _state;
      onError?.call('Fehler bei Sprachinitialisierung: $e');
    }
  }

  Future<void> speak(String text) async {
    _state = VoiceState.speaking;
    stateNotifier.value = _state;
    try {
      if (_ttsReady) {
        await _tts.speak(text);
      } else {
        try {
          await _tts.setLanguage('de-DE');
          await _tts.setSpeechRate(0.45);
          _ttsReady = true;
          await _tts.speak(text);
        } catch (e) {
          debugPrint('TTS speak error: $e');
          onError?.call('Sprachausgabe nicht verfügbar');
          _state = VoiceState.idle;
          stateNotifier.value = _state;
        }
      }
    } catch (e) {
      debugPrint('TTS speak error: $e');
      _state = VoiceState.idle;
      stateNotifier.value = _state;
    }
  }

  Future<void> startListening() async {
    if (!_initialized) await initialize();
    if (!_initialized) {
      onError?.call('Spracherkennung nicht initialisiert.');
      return;
    }
    if (_isListening) return;

    final hasPerm = await _speech.hasPermission;
    if (!hasPerm) {
      _initialized = await _speech.initialize();
      if (!_initialized) {
        _state = VoiceState.noPermission;
        stateNotifier.value = _state;
        onError?.call('Mikrofonberechtigung erforderlich.');
        return;
      }
    }

    _isListening = true;
    _state = VoiceState.listening;
    stateNotifier.value = _state;

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            final text = result.recognizedWords.toLowerCase().trim();
            debugPrint('Erkannt: $text');
            if (text.isNotEmpty) {
              onResult?.call(text);
              _routeCommand(text);
            }
          }
        },
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        localeId: 'de_DE',
        cancelOnError: true,
        partialResults: false,
      );
    } catch (e) {
      debugPrint('listen error: $e');
      _isListening = false;
      _state = VoiceState.error;
      stateNotifier.value = _state;
      onError?.call('Fehler beim Zuhören: $e');
    }
  }

  Future<void> stopListening() async {
    _isListening = false;
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('stop error: $e');
    }
    _state = VoiceState.idle;
    stateNotifier.value = _state;
  }

  /// Route command: simple direct or complex multi-step
  void _routeCommand(String text) {
    // Check direct commands first
    for (final entry in directCommands.entries) {
      if (text.contains(entry.key)) {
        onCommand?.call(entry.value);
        return;
      }
    }
    // Route to complex task executor
    onComplexCommand?.call(text);
  }

  void dispose() {
    _speech.stop();
    _tts.stop();
  }
}
