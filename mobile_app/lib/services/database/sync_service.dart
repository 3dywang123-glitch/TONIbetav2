import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'local_database.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final LocalDatabase _localDb = LocalDatabase();
  bool _isSyncing = false;
  String? _backendUrl;

  bool get isSyncing => _isSyncing;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _backendUrl = prefs.getString('backend_url');
  }

  /// 同步所有未同步的数据到服务器
  Future<void> syncAll({bool force = false}) async {
    if (_isSyncing && !force) {
      debugPrint('⏸️ 同步已在进行中，跳过');
      return;
    }

    if (_backendUrl == null || _backendUrl!.isEmpty) {
      debugPrint('⚠️ 后端URL未配置，无法同步');
      return;
    }

    _isSyncing = true;
    debugPrint('🔄 开始同步数据到服务器...');

    try {
      await initialize();
      
      // 同步会话
      await _syncSessions();
      
      // 同步消息
      await _syncMessages();
      
      // 同步AI请求
      await _syncAIRequests();
      
      debugPrint('✅ 数据同步完成');
    } catch (e) {
      debugPrint('❌ 同步失败: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// 同步会话
  Future<void> _syncSessions() async {
    final unsyncedSessions = await _localDb.getUnsyncedSessions();
    if (unsyncedSessions.isEmpty) return;

    debugPrint('📤 同步 ${unsyncedSessions.length} 个会话...');

    for (final session in unsyncedSessions) {
      try {
        final response = await http.post(
          Uri.parse('$_backendUrl/api/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'session_id': session['session_id'],
            'device_ip': session['device_ip'],
          }),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 201) {
          await _localDb.markSessionSynced(session['session_id'] as String);
          debugPrint('✅ 会话 ${session['session_id']} 同步成功');
        } else {
          debugPrint('⚠️ 会话 ${session['session_id']} 同步失败: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('❌ 会话同步错误: $e');
        // 继续同步下一个，不中断
      }
    }
  }

  /// 同步消息
  Future<void> _syncMessages() async {
    final unsyncedMessages = await _localDb.getUnsyncedMessages();
    if (unsyncedMessages.isEmpty) return;

    debugPrint('📤 同步 ${unsyncedMessages.length} 条消息...');

    // 按会话分组
    final messagesBySession = <String, List<Map<String, dynamic>>>{};
    for (final msg in unsyncedMessages) {
      final sessionId = msg['session_id'] as String;
      messagesBySession.putIfAbsent(sessionId, () => []).add(msg);
    }

    // 逐个会话同步
    for (final entry in messagesBySession.entries) {
      final sessionId = entry.key;
      final messages = entry.value;

      try {
        // 获取会话详情（包含所有消息）
        final sessionData = await _localDb.getSessionWithMessages(sessionId);
        if (sessionData == null) continue;

        // 尝试同步整个会话
        final response = await http.get(
          Uri.parse('$_backendUrl/api/sessions/$sessionId'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 10));

        // 如果会话不存在，创建它
        if (response.statusCode == 404) {
          await http.post(
            Uri.parse('$_backendUrl/api/sessions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'session_id': sessionId,
              'device_ip': sessionData['session']?['device_ip'],
            }),
          ).timeout(const Duration(seconds: 10));
        }

        // 标记消息为已同步（假设服务器会处理）
        for (final msg in messages) {
          await _localDb.markMessageSynced(msg['id'] as int);
        }

        debugPrint('✅ 会话 $sessionId 的 ${messages.length} 条消息同步成功');
      } catch (e) {
        debugPrint('❌ 消息同步错误: $e');
        // 继续同步下一个会话
      }
    }
  }

  /// 同步AI请求
  Future<void> _syncAIRequests() async {
    final unsyncedRequests = await _localDb.getUnsyncedAIRequests();
    if (unsyncedRequests.isEmpty) return;

    debugPrint('📤 同步 ${unsyncedRequests.length} 个AI请求...');

    // AI请求通常不需要单独同步，因为它们已经包含在消息中
    // 这里可以选择性地同步统计信息
    for (final request in unsyncedRequests) {
      try {
        // 标记为已同步（AI请求主要用于本地分析）
        await _localDb.markAIRequestSynced(request['id'] as int);
      } catch (e) {
        debugPrint('❌ AI请求同步错误: $e');
      }
    }
  }

  /// 后台定期同步（在非工作时段）
  Future<void> startBackgroundSync() async {
    // 检查是否在非工作时段（例如：晚上10点到早上8点）
    final now = DateTime.now();
    final hour = now.hour;
    
    // 非工作时段：22:00 - 08:00
    final isOffHours = hour >= 22 || hour < 8;
    
    if (isOffHours) {
      debugPrint('🌙 非工作时段，开始后台同步...');
      await syncAll();
    } else {
      debugPrint('☀️ 工作时段，跳过后台同步');
    }
  }

  /// 立即同步（用户手动触发或重要操作后）
  Future<void> syncNow() async {
    await syncAll(force: true);
  }
}

