import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../models/chat_message.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'toni_local.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Sessions table
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT UNIQUE NOT NULL,
        device_ip TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Messages table
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        message_type TEXT NOT NULL,
        content TEXT NOT NULL,
        expert_type TEXT,
        camera_action TEXT,
        image_path TEXT,
        created_at INTEGER NOT NULL,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (session_id) REFERENCES sessions(session_id) ON DELETE CASCADE
      )
    ''');

    // AI requests table
    await db.execute('''
      CREATE TABLE ai_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT,
        request_type TEXT NOT NULL,
        user_text TEXT,
        image_size INTEGER,
        expert_type TEXT,
        response_time_ms INTEGER,
        created_at INTEGER NOT NULL,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (session_id) REFERENCES sessions(session_id) ON DELETE SET NULL
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_sessions_session_id ON sessions(session_id)');
    await db.execute('CREATE INDEX idx_sessions_synced ON sessions(synced)');
    await db.execute('CREATE INDEX idx_messages_session_id ON messages(session_id)');
    await db.execute('CREATE INDEX idx_messages_synced ON messages(synced)');
    await db.execute('CREATE INDEX idx_ai_requests_synced ON ai_requests(synced)');
  }

  // Session operations
  Future<int> insertSession({
    required String sessionId,
    String? deviceIp,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    return await db.insert(
      'sessions',
      {
        'session_id': sessionId,
        'device_ip': deviceIp,
        'created_at': now,
        'updated_at': now,
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedSessions() async {
    final db = await database;
    return await db.query(
      'sessions',
      where: 'synced = ?',
      whereArgs: [0],
    );
  }

  Future<void> markSessionSynced(String sessionId) async {
    final db = await database;
    await db.update(
      'sessions',
      {'synced': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  // Message operations
  Future<int> insertMessage({
    required String sessionId,
    required String messageType,
    required String content,
    String? expertType,
    String? cameraAction,
    String? imagePath,
  }) async {
    final db = await database;
    
    return await db.insert(
      'messages',
      {
        'session_id': sessionId,
        'message_type': messageType,
        'content': content,
        'expert_type': expertType,
        'camera_action': cameraAction,
        'image_path': imagePath,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'synced': 0,
      },
    );
  }

  Future<List<ChatMessage>> getSessionMessages(String sessionId) async {
    final db = await database;
    final results = await db.query(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );

    return results.map((row) {
      return ChatMessage(
        id: row['id'].toString(),
        text: row['content'] as String,
        isUser: row['message_type'] == 'user',
        isSecretary: row['message_type'] == 'secretary',
        timestamp: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        expertType: row['expert_type'] as String?,
        sessionId: sessionId,
        // Note: imageData will be loaded separately if needed
      );
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getUnsyncedMessages() async {
    final db = await database;
    return await db.query(
      'messages',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> markMessageSynced(int messageId) async {
    final db = await database;
    await db.update(
      'messages',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  // AI Request operations
  Future<int> insertAIRequest({
    String? sessionId,
    required String requestType,
    String? userText,
    int? imageSize,
    String? expertType,
    int? responseTimeMs,
  }) async {
    final db = await database;
    
    return await db.insert(
      'ai_requests',
      {
        'session_id': sessionId,
        'request_type': requestType,
        'user_text': userText,
        'image_size': imageSize,
        'expert_type': expertType,
        'response_time_ms': responseTimeMs,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'synced': 0,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedAIRequests() async {
    final db = await database;
    return await db.query(
      'ai_requests',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> markAIRequestSynced(int requestId) async {
    final db = await database;
    await db.update(
      'ai_requests',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [requestId],
    );
  }

  // Get recent sessions for history
  Future<List<Map<String, dynamic>>> getRecentSessions({int limit = 50}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        s.*,
        COUNT(m.id) as message_count
      FROM sessions s
      LEFT JOIN messages m ON s.session_id = m.session_id
      GROUP BY s.id
      ORDER BY s.updated_at DESC
      LIMIT ?
    ''', [limit]);
  }

  // Get session with messages
  Future<Map<String, dynamic>?> getSessionWithMessages(String sessionId) async {
    final db = await database;
    final session = await db.query(
      'sessions',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );

    if (session.isEmpty) return null;

    final messages = await getSessionMessages(sessionId);
    
    return {
      'session': session.first,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }

  // Cleanup old synced data (optional, to save space)
  Future<void> cleanupOldSyncedData({int daysToKeep = 30}) async {
    final db = await database;
    final cutoffTime = DateTime.now().subtract(Duration(days: daysToKeep)).millisecondsSinceEpoch;
    
    await db.delete(
      'messages',
      where: 'synced = 1 AND created_at < ?',
      whereArgs: [cutoffTime],
    );
    
    await db.delete(
      'ai_requests',
      where: 'synced = 1 AND created_at < ?',
      whereArgs: [cutoffTime],
    );
  }

  /// 清除所有本地数据（用于清理缓存）
  Future<void> clearAllData() async {
    final db = await database;
    
    try {
      // 删除所有表的数据（保留表结构）
      await db.delete('ai_requests');
      await db.delete('messages');
      await db.delete('sessions');
      
      debugPrint('✅ 本地数据库已清空');
    } catch (e) {
      debugPrint('❌ 清空数据库失败: $e');
      rethrow;
    }
  }

  /// 获取数据库文件大小（字节）
  Future<int> getDatabaseSize() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = join(documentsDirectory.path, 'toni_local.db');
      final file = File(dbPath);
      
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      debugPrint('获取数据库大小失败: $e');
      return 0;
    }
  }
}
