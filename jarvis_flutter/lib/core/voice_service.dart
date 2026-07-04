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

  static const Map<String, String> commands = {
    'öffne youtube': 'youtube',
    'öffne google': 'google',
    'öffne chrome': 'chrome',
    'öffne discord': 'discord',
    'öffne spotify': 'spotify',
    'öffne notepad': 'notepad',
    'öffne editor': 'notepad',
    'beende jarvis': 'shutdown',
    'beenden': 'shutdown',
  };

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      // Initialize speech recognition
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

        // Check if TTS engine is available
        final engines = await _tts.getEngines();
        if (engines != null && engines.isNotEmpty) {
          _ttsReady = true;
        }

        // Add TTS completion listener
        _tts.setCompletionHandler(() {
          _state = VoiceState.idle;
          stateNotifier.value = _state;
        });
      } catch (e) {
        debugPrint('TTS init warning: $e');
        _ttsReady = false;
      }

      if (!_initialized) {
        _state = VoiceState.noPermission;
        stateNotifier.value = _state;
        onError?.call('Keine Mikrofonberechtigung. Bitte erlaube das Mikrofon in den App-Einstellungen.');
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
        // Try to re-initialize TTS
        try {
          await _tts.setLanguage('de-DE');
          await _tts.setSpeechRate(0.45);
          _ttsReady = true;
          await _tts.speak(text);
        } catch (e) {
          debugPrint('TTS speak error: $e');
          onError?.call('Sprachausgabe nicht verfügbar (TTS Engine fehlt)');
          _state = VoiceState.idle;
          stateNotifier.value = _state;
        }
      }
    } catch (e) {
      debugPrint('TTS speak error: $e');
      onError?.call('Sprachausgabe-Fehler: $e');
      _state = VoiceState.idle;
      stateNotifier.value = _state;
    }
  }

  Future<void> startListening() async {
    if (!_initialized) await initialize();

    if (!_initialized) {
      onError?.call('Spracherkennung nicht initialisiert. Mikrofonberechtigung fehlt.');
      return;
    }

    if (_isListening) return;

    // Check permission
    final hasPerm = await _speech.hasPermission;
    if (!hasPerm) {
      // Try to initialize again (this will request permission)
      _initialized = await _speech.initialize();
      if (!_initialized) {
        _state = VoiceState.noPermission;
        stateNotifier.value = _state;
        onError?.call('Mikrofonberechtigung erforderlich. Bitte in den Einstellungen aktivieren.');
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
              _processCommand(text);
            }
          }
        },
        listenFor: const Duration(seconds: 10),
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

  void _processCommand(String text) {
    for (final entry in commands.entries) {
      if (text.contains(entry.key)) {
        onCommand?.call(entry.value);
        return;
      }
    }
  }

  void dispose() {
    _speech.stop();
    _tts.stop();
  }
}
