import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:sound_stream/sound_stream.dart';
import 'package:permission_handler/permission_handler.dart';

class OfflineAsrService extends ChangeNotifier {
  static final OfflineAsrService _instance = OfflineAsrService._internal();
  factory OfflineAsrService() => _instance;
  OfflineAsrService._internal();

  final RecorderStream _recorder = RecorderStream();
  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;
  
  // 状态流：把识别到的字实时吐给 UI
  final StreamController<String> _textController = StreamController<String>.broadcast();
  Stream<String> get onTextUpdated => _textController.stream;

  bool _isReady = false;
  bool _isListening = false;
  String _currentText = '';

  String get currentText => _currentText;
  bool get isReady => _isReady;
  bool get isListening => _isListening;

  String? _initError;

  String? get initError => _initError;

  Future<void> init() async {
    if (_isReady) return;
    debugPrint("👂 [OfflineASR] 正在装载听觉模型...");
    _initError = null;

    try {
      await _recorder.initialize();

      // 1. 拷贝模型文件到本地
      String tokens = await _copyAssetToLocal('assets/model/tokens_asr.txt');
      String encoder = await _copyAssetToLocal('assets/model/encoder-epoch-99-avg-1.onnx');
      String decoder = await _copyAssetToLocal('assets/model/decoder-epoch-99-avg-1.onnx');
      String joiner = await _copyAssetToLocal('assets/model/joiner-epoch-99-avg-1.onnx');

      // 2. 配置识别器 (Zipformer)
      final config = sherpa.OnlineRecognizerConfig(
        model: sherpa.OnlineModelConfig(
          transducer: sherpa.OnlineTransducerModelConfig(
            encoder: encoder,
            decoder: decoder,
            joiner: joiner,
          ),
          tokens: tokens,
          numThreads: 1,
          provider: 'cpu',
          modelType: 'zipformer',
        ),
        enableEndpoint: true, // 启用自动断句 (VAD)
        ruleFsts: '',
      );

      _recognizer = sherpa.OnlineRecognizer(config);
      _isReady = true;
      debugPrint("🚀 [OfflineASR] 听觉系统就绪！");

      // 3. 监听麦克风数据流
      _recorder.audioStream.listen((data) {
        if (_isListening && _recognizer != null && _stream != null) {
          // 把 Uint8List 转成 Float32List 喂给 Sherpa
          // SoundStream 返回的是 PCM 16bit, 需要转换
          final samples = _convertBytesToFloat32(data);
          _stream!.acceptWaveform(samples: samples, sampleRate: 16000);
          
          // 执行解码
          while (_recognizer!.isReady(_stream!)) {
            _recognizer!.decode(_stream!);
          }

          // 获取结果
          final result = _recognizer!.getResult(_stream!);
          if (result.text.isNotEmpty) {
            _currentText = result.text;
            _textController.add(result.text); // 推送给 UI
            notifyListeners();
          }
        }
      });
    } catch (e) {
      _initError = e.toString();
      debugPrint("❌ [OfflineASR] 初始化失败: $e");
      notifyListeners();
    }
  }

  Future<void> startListening() async {
    if (!_isReady) {
      await init();
    }
    if (!_isReady) return;
    
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      debugPrint("❌ 麦克风权限未授予");
      return;
    }

    _stream = _recognizer!.createStream();
    await _recorder.start();
    _isListening = true;
    _currentText = '';
    _textController.add(''); // 清空上一句
    notifyListeners();
  }

  Future<void> stopListening() async {
    _isListening = false;
    await _recorder.stop();
    _stream?.free();
    _stream = null;
    notifyListeners();
  }

  void reset() {
    _currentText = '';
    _textController.add('');
    notifyListeners();
  }

  // --- 辅助工具 ---
  
  // PCM 16bit (Bytes) -> Float32 (-1.0 to 1.0)
  Float32List _convertBytesToFloat32(Uint8List data) {
    final int16Data = Int16List.view(data.buffer);
    final float32Data = Float32List(int16Data.length);
    for (int i = 0; i < int16Data.length; i++) {
      float32Data[i] = int16Data[i] / 32768.0;
    }
    return float32Data;
  }

  Future<String> _copyAssetToLocal(String assetPath) async {
    final docDir = await getApplicationDocumentsDirectory();
    final fileName = assetPath.split('/').last;
    final file = File('${docDir.path}/$fileName');
    if (!await file.exists()) {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      await file.writeAsBytes(bytes, flush: true);
    }
    return file.path;
  }

  @override
  void dispose() {
    stopListening();
    _textController.close();
    super.dispose();
  }
}

