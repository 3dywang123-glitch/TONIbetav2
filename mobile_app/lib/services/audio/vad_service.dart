import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VadService extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isSpeechDetected = false;
  Timer? _silenceTimer;
  static const Duration silenceThreshold = Duration(milliseconds: 1500);
  static const double speechThreshold = -40.0; // dB

  final StreamController<bool> _speechStateController = StreamController<bool>.broadcast();
  Stream<bool> get speechState => _speechStateController.stream;

  bool get isRecording => _isRecording;
  bool get isSpeechDetected => _isSpeechDetected;

  Future<bool> startRecording() async {
    if (_isRecording) return true;

    try {
      if (await _recorder.hasPermission()) {
        // VAD不需要保存文件，使用临时路径
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/vad_temp.m4a';
        
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: tempPath,
        );
        _isRecording = true;
        notifyListeners();

        // Start monitoring audio levels
        _monitorAudioLevel();
        return true;
      } else {
        debugPrint('Microphone permission denied');
        return false;
      }
    } catch (e) {
      debugPrint('Start recording error: $e');
      return false;
    }
  }

  StreamSubscription<Amplitude>? _amplitudeSubscription;

  void _monitorAudioLevel() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _recorder.onAmplitudeChanged(
      const Duration(milliseconds: 100),
    ).listen((amplitude) {
      if (!_isRecording) return;

      final isSpeech = amplitude.current > speechThreshold;

      if (isSpeech != _isSpeechDetected) {
        _isSpeechDetected = isSpeech;
        _speechStateController.add(_isSpeechDetected);
        notifyListeners();

        if (_isSpeechDetected) {
          _silenceTimer?.cancel();
        } else {
          _silenceTimer = Timer(silenceThreshold, () {
            if (!_isSpeechDetected) {
              _onSilenceDetected();
            }
          });
        }
      }
    });
  }

  void _onSilenceDetected() {
    debugPrint('Silence detected - speech ended');
    _speechStateController.add(false);
    notifyListeners();
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      _isSpeechDetected = false;
      _silenceTimer?.cancel();
      notifyListeners();
      return path;
    } catch (e) {
      debugPrint('Stop recording error: $e');
      return null;
    }
  }

  Future<void> cancelRecording() async {
    if (_isRecording) {
      await _recorder.stop();
      _isRecording = false;
      _isSpeechDetected = false;
      _silenceTimer?.cancel();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _recorder.dispose();
    _speechStateController.close();
    super.dispose();
  }
}

