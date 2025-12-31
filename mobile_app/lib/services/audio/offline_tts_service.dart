import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:audioplayers/audioplayers.dart';

class OfflineTtsService {
  static final OfflineTtsService _instance = OfflineTtsService._internal();
  factory OfflineTtsService() => _instance;
  OfflineTtsService._internal();

  sherpa.OfflineTts? _tts;
  final AudioPlayer _player = AudioPlayer();
  bool _isReady = false;
  String? _initError;

  // 🎧 选角配置 (AIShell3 ID 范围 0-173)
  final int _secretaryId = 167; // 甜美
  final int _expertId = 120;    // 沉稳

  bool get isReady => _isReady;
  String? get initError => _initError;

  Future<void> init() async {
    if (_isReady) return;
    debugPrint("📦 [OfflineTTS] 正在装载战术语音模型...");
    _initError = null;

    try {
      // 1. 拷贝核心文件
      String modelPath = await _copyAssetToLocal('assets/model/vits-aishell3.onnx');
      String tokensPath = await _copyAssetToLocal('assets/model/tokens_tts.txt');
      String lexiconPath = await _copyAssetToLocal('assets/model/lexicon.txt');
      
      // 2. 拷贝规则文件 (让它能读懂 "1998年")
      String rulePath = await _copyAssetToLocal('assets/model/rule.far');
      await _copyAssetToLocal('assets/model/date.fst');
      await _copyAssetToLocal('assets/model/number.fst');
      await _copyAssetToLocal('assets/model/phone.fst');
      await _copyAssetToLocal('assets/model/new_heteronym.fst');

      // 3. 配置引擎
      final config = sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          vits: sherpa.OfflineTtsVitsModelConfig(
            model: modelPath,
            lexicon: lexiconPath,
            tokens: tokensPath,
          ),
          numThreads: 2,
          debug: false,
          provider: 'cpu', // 手机端用 CPU
        ),
        ruleFsts: rulePath, // 加载规则
      );

      _tts = sherpa.OfflineTts(config);
      _isReady = true;
      debugPrint("🚀 [OfflineTTS] 引擎就绪！");
    } catch (e) {
      _initError = e.toString();
      debugPrint("❌ [OfflineTTS] 初始化失败: $e");
    }
  }

  /// 说话核心方法
  Future<void> speak(String text, {required bool isSecretary}) async {
    if (!_isReady || _tts == null) {
      debugPrint("⚠️ 引擎未就绪");
      return;
    }
    
    // 停止正在播放的声音
    await _player.stop();

    int sid = isSecretary ? _secretaryId : _expertId;
    double speed = isSecretary ? 1.1 : 0.9; // 语速调整

    debugPrint("🔊 生成中 ($sid): $text");
    
    try {
      // 1. 生成原始音频数据 (PCM Float32)
      final audio = _tts!.generate(text: text, sid: sid, speed: speed);
      
      // 2. 转换为 WAV 格式 (关键步骤)
      // Sherpa 输出是 sampleRate=22050 的单声道音频
      final wavBytes = _createWavHeader(audio.samples, audio.sampleRate);

      // 3. 写入临时文件
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_speech.wav');
      await tempFile.writeAsBytes(wavBytes);

      // 4. 播放
      await _player.play(DeviceFileSource(tempFile.path));
    } catch (e) {
      debugPrint("❌ TTS 生成失败: $e");
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }

  /// 辅助：把 Assets 拷贝到本地沙盒
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

  /// 核心黑科技：手动构建 WAV 文件头
  /// 让播放器能听懂 Raw Data
  Uint8List _createWavHeader(Float32List samples, int sampleRate) {
    int numSamples = samples.length;
    int numChannels = 1;
    int bitsPerSample = 16;
    
    int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    int blockAlign = numChannels * bitsPerSample ~/ 8;
    int subChunk2Size = numSamples * numChannels * bitsPerSample ~/ 8;
    int chunkSize = 36 + subChunk2Size;

    final header = ByteData(44);
    
    // RIFF chunk
    _writeString(header, 0, 'RIFF');
    header.setUint32(4, chunkSize, Endian.little);
    _writeString(header, 8, 'WAVE');

    // fmt chunk
    _writeString(header, 12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // Subchunk1Size
    header.setUint16(20, 1, Endian.little); // AudioFormat (1 = PCM)
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);

    // data chunk
    _writeString(header, 36, 'data');
    header.setUint32(40, subChunk2Size, Endian.little);

    // Convert Float32 samples (-1.0 to 1.0) to Int16 (-32768 to 32767)
    final pcmData = Int16List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      double s = samples[i];
      if (s > 1.0) s = 1.0;
      if (s < -1.0) s = -1.0;
      pcmData[i] = (s * 32767).toInt();
    }

    final wavBytes = Uint8List(44 + pcmData.lengthInBytes);
    wavBytes.setRange(0, 44, header.buffer.asUint8List());
    wavBytes.setRange(44, wavBytes.length, pcmData.buffer.asUint8List());

    return wavBytes;
  }

  void _writeString(ByteData data, int offset, String value) {
    for (int i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }
}

