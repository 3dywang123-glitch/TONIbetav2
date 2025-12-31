import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechRecognitionService extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _firstCommand = '';
  String _fullContext = '';
  Timer? _firstCommandTimer;
  bool _firstCommandCaptured = false;

  String get firstCommand => _firstCommand;
  String get fullContext => _fullContext;
  bool get isListening => _isListening;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final available = await _speech.initialize(
        onError: (error) {
          debugPrint('Speech recognition error: $error');
        },
        onStatus: (status) {
          debugPrint('Speech recognition status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            notifyListeners();
          }
        },
      );

      _isInitialized = available;
      return available;
    } catch (e) {
      debugPrint('Speech initialization error: $e');
      return false;
    }
  }

  Future<void> startListening({
    Duration firstCommandDuration = const Duration(seconds: 5),
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isListening) return;

    _firstCommand = '';
    _fullContext = '';
    _firstCommandCaptured = false;

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _fullContext = result.recognizedWords;
            notifyListeners();
          } else {
            final currentText = result.recognizedWords;
            _fullContext = currentText;

            // Capture first command if not already captured
            if (!_firstCommandCaptured) {
              _firstCommand = currentText;
              notifyListeners();

              // Set timer to mark first command as captured
              _firstCommandTimer?.cancel();
              _firstCommandTimer = Timer(firstCommandDuration, () {
                _firstCommandCaptured = true;
                debugPrint('First command captured: $_firstCommand');
              });
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'zh_CN', // Chinese locale, adjust as needed
      );

      _isListening = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Start listening error: $e');
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
      _isListening = false;
      _firstCommandTimer?.cancel();

      // If first command not captured yet, use current text
      if (!_firstCommandCaptured && _fullContext.isNotEmpty) {
        _firstCommand = _fullContext;
        _firstCommandCaptured = true;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Stop listening error: $e');
    }
  }

  void reset() {
    _firstCommand = '';
    _fullContext = '';
    _firstCommandCaptured = false;
    _firstCommandTimer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _firstCommandTimer?.cancel();
    _speech.cancel();
    super.dispose();
  }
}

