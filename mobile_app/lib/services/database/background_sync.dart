import 'dart:async';
import 'package:flutter/foundation.dart';
import 'sync_service.dart';

/// 后台同步管理器
/// 在非工作时段自动同步数据到服务器
class BackgroundSyncManager {
  static final BackgroundSyncManager _instance = BackgroundSyncManager._internal();
  factory BackgroundSyncManager() => _instance;
  BackgroundSyncManager._internal();

  final SyncService _syncService = SyncService();
  Timer? _syncTimer;
  bool _isRunning = false;

  /// 启动后台同步
  void start() {
    if (_isRunning) {
      debugPrint('后台同步已在运行');
      return;
    }

    _isRunning = true;
    debugPrint('🔄 启动后台同步管理器');

    // 立即检查一次
    _checkAndSync();

    // 每小时检查一次
    _syncTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _checkAndSync();
    });
  }

  /// 停止后台同步
  void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _isRunning = false;
    debugPrint('⏸️ 停止后台同步管理器');
  }

  /// 检查是否在非工作时段并同步
  Future<void> _checkAndSync() async {
    final now = DateTime.now();
    final hour = now.hour;
    
    // 非工作时段：22:00 - 08:00 或 周末
    final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    final isOffHours = hour >= 22 || hour < 8;
    
    if (isOffHours || isWeekend) {
      debugPrint('🌙 非工作时段，开始后台同步...');
      await _syncService.syncAll();
    } else {
      debugPrint('☀️ 工作时段 ($hour:00)，跳过后台同步');
    }
  }

  /// 立即同步（用户手动触发）
  Future<void> syncNow() async {
    debugPrint('🔄 用户触发立即同步');
    await _syncService.syncAll(force: true);
  }
}

