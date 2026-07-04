import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

enum VoiceState { idle, listening, speaking, error }

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _isListening = false;

  VoiceState _state = VoiceState.idle;
  VoiceState get state => _state;

  final ValueNotifier<VoiceState> stateNotifier = ValueNotifier(VoiceState.idle);

  // Command callback
  void Function(String command)? onCommand;

  static const Map<String, String> commands = {
    'öffne youtube': 'youtube',
    'öffne google': 'google',
    'öffne chrome': 'chrome',
    'öffne discord': 'discord',
    'öffne spotify': 'spotify',
    'öffne notepad': 'notepad',
    'öffne editor': 'notepad',
    'beende jarvis': 'shutdown',
  };

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _initialized = await _speech.initialize();
      await _tts.setLanguage('de-DE');
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(0.9);
      await _tts.setPitch(1.0);
    } catch (e) {
      debugPrint('Voice init error: $e');
      _state = VoiceState.error;
      stateNotifier.value = _state;
    }
  }

  Future<void> speak(String text) async {
    _state = VoiceState.speaking;
    stateNotifier.value = _state;
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS error: $e');
    }
    _state = VoiceState.idle;
    stateNotifier.value = _state;
  }

  Future<void> startListening() async {
    if (!_initialized) await initialize();
    if (_isListening) return;

    _isListening = true;
    _state = VoiceState.listening;
    stateNotifier.value = _state;

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          final text = result.recognizedWords.toLowerCase().trim();
          debugPrint('Erkannt: $text');
          _processCommand(text);
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      localeId: 'de_DE',
    );
  }

  Future<void> stopListening() async {
    _isListening = false;
    await _speech.stop();
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
