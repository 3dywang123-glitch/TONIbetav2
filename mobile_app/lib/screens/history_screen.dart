import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database/local_database.dart';
import '../services/database/sync_service.dart';
import 'session_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final LocalDatabase _localDb = LocalDatabase();
  final SyncService _syncService = SyncService();
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    // 初始化同步服务
    _syncService.initialize();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 优先从本地数据库加载
      final localSessions = await _localDb.getRecentSessions(limit: 50);
      
      // 转换时间戳为可读格式
      final sessions = localSessions.map((session) {
        return {
          ...session,
          'created_at': DateTime.fromMillisecondsSinceEpoch(session['created_at'] as int).toIso8601String(),
          'updated_at': DateTime.fromMillisecondsSinceEpoch(session['updated_at'] as int).toIso8601String(),
        };
      }).toList();

      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });

      // 后台尝试从服务器同步（不阻塞UI）
      _trySyncFromServer();
    } catch (e) {
      setState(() {
        _error = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _trySyncFromServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backendUrl = prefs.getString('backend_url');
      
      if (backendUrl != null && backendUrl.isNotEmpty) {
        // 后台同步
        _syncService.syncAll();
      }
    } catch (e) {
      debugPrint('后台同步失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: const Text('会话历史'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSessions,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _sessions.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无历史会话',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        return _buildSessionCard(session);
                      },
                    ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final sessionId = session['session_id'] as String? ?? '';
    final deviceIp = session['device_ip'] as String? ?? '';
    final messageCount = session['message_count'] as int? ?? 0;
    final updatedAt = session['updated_at'] != null
        ? DateTime.parse(session['updated_at'])
        : DateTime.now();

    return Card(
      color: Colors.grey[900]!.withOpacity(0.8),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.cyanAccent.withOpacity(0.2),
          child: const Icon(Icons.chat_bubble, color: Colors.cyanAccent),
        ),
        title: Text(
          '会话 ${sessionId.substring(0, sessionId.length > 8 ? 8 : sessionId.length)}',
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '$messageCount 条消息',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            if (deviceIp.isNotEmpty)
              Text(
                '设备: $deviceIp',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
          ],
        ),
        trailing: Text(
          _formatDate(updatedAt),
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SessionDetailScreen(sessionId: sessionId),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '今天 ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return '昨天 ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}
