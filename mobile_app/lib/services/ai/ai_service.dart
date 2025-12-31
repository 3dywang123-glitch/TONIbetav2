import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../audio/offline_tts_service.dart';
import '../database/local_database.dart';
import '../database/sync_service.dart';

class AiService extends ChangeNotifier {
  final OfflineTtsService _tts = OfflineTtsService();
  final LocalDatabase _localDb = LocalDatabase();
  final SyncService _syncService = SyncService();
  String? _backendUrl;
  String? _currentSessionId;
  
  String? get backendUrl => _backendUrl;
  String? _secretaryReply;
  String? _expertType;
  String? _cameraAction;
  String? _expertReply;
  int _burstCount = 0;

  String? get secretaryReply => _secretaryReply;
  String? get expertType => _expertType;
  String? get cameraAction => _cameraAction;
  String? get expertReply => _expertReply;
  int get burstCount => _burstCount;

  Future<void> initialize({String? backendUrl}) async {
    if (backendUrl != null) {
      _backendUrl = backendUrl;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('backend_url', backendUrl);
    } else {
      // Load from preferences
      final prefs = await SharedPreferences.getInstance();
      _backendUrl = prefs.getString('backend_url') ?? 'http://localhost:3000';
    }
    await _tts.init();
  }

  Future<Map<String, dynamic>?> callSecretaryAi({
    required String text,
    required Uint8List imageData,
    String secretaryStyle = 'cute',
    String? sessionId,
    String? deviceIp,
  }) async {
    if (_backendUrl == null) {
      await initialize();
    }

    try {
      final base64Image = base64Encode(imageData);
      final response = await http.post(
        Uri.parse('$_backendUrl/api/secretary'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': text,
          'image': base64Image,
          'secretary_style': secretaryStyle,
          'session_id': sessionId,
          'device_ip': deviceIp,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _secretaryReply = data['reply'] as String?;
        _expertType = data['expert'] as String?;
        _cameraAction = data['camera_action'] as String?;
        _burstCount = (data['burst_count'] as int?) ?? 0;
        
        // 保存返回的session_id（如果后端返回了）
        if (data['session_id'] != null) {
          // 可以在这里保存session_id到当前会话
        }
        
        notifyListeners();

        // Play TTS
        if (_secretaryReply != null) {
          await _tts.speak(_secretaryReply!, isSecretary: true);
        }

        return data;
      } else {
        debugPrint('Secretary AI error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Secretary AI call error: $e');
      return null;
    }
  }

  Future<String?> callExpertAi({
    required String userContext,
    required String secretaryContext,
    required Uint8List imageData,
    required String picRequire, // "normal" or "wide"
    String? sessionId,
    String? deviceIp,
    List<Uint8List>? burstImages, // 连拍图像列表（可选）
  }) async {
    if (_backendUrl == null) {
      await initialize();
    }

    // 使用当前会话ID
    final currentSessionId = sessionId ?? _currentSessionId;
    if (currentSessionId == null) {
      debugPrint('⚠️ 无会话ID，无法保存专家回复');
    }

    // 保存图像到本地
    String? imagePath;
    try {
      final tempDir = await getTemporaryDirectory();
      final imageFile = File('${tempDir.path}/img_hd_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await imageFile.writeAsBytes(imageData);
      imagePath = imageFile.path;
    } catch (e) {
      debugPrint('保存图像失败: $e');
    }

    final startTime = DateTime.now().millisecondsSinceEpoch;
    String? reply;

    // 1. 尝试调用AI（如果后端可用）
    if (_backendUrl != null && _backendUrl!.isNotEmpty) {
      try {
        final base64Image = base64Encode(imageData);
        final response = await http.post(
          Uri.parse('$_backendUrl/api/expert'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'user_context': userContext,
            'secretary_context': secretaryContext,
            'image': base64Image,
            'pic_require': picRequire,
            'expert': expertType ?? 'general_engineer',
            'session_id': currentSessionId,
            'device_ip': deviceIp,
          }),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          reply = data['reply'] as String?;
        }
      } catch (e) {
        debugPrint('⚠️ AI调用失败，使用本地模式: $e');
      }
    }

    // 2. 如果没有回复，生成默认回复
    if (reply == null || reply.isEmpty) {
      reply = '正在分析中，请稍候...';
    }

    _expertReply = reply;
    notifyListeners();

    // 3. 保存到本地数据库
    if (currentSessionId != null) {
      try {
        await _localDb.insertMessage(
          sessionId: currentSessionId,
          messageType: 'expert',
          content: reply,
          expertType: expertType,
          imagePath: imagePath,
        );

        final responseTime = DateTime.now().millisecondsSinceEpoch - startTime;
        await _localDb.insertAIRequest(
          sessionId: currentSessionId,
          requestType: 'expert',
          userText: userContext,
          imageSize: imageData.length,
          expertType: expertType,
          responseTimeMs: responseTime,
        );
      } catch (e) {
        debugPrint('保存专家回复失败: $e');
      }
    }

    // 4. 播放TTS
    try {
      await _tts.speak(reply, isSecretary: false);
    } catch (e) {
      debugPrint('TTS error: $e');
    }

    // 5. 后台异步同步
    _syncService.syncAll().catchError((e) {
      debugPrint('后台同步失败: $e');
    });

    return reply;
  }

  void reset() {
    _secretaryReply = null;
    _expertType = null;
    _cameraAction = null;
    _expertReply = null;
    _burstCount = 0;
    _currentSessionId = null;
    notifyListeners();
  }
  
  /// 设置当前会话ID
  void setSessionId(String sessionId) {
    _currentSessionId = sessionId;
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}

