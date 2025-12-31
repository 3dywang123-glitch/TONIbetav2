import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  static const String _userIdKey = 'user_id';
  static const String _userTypeKey = 'user_type';
  String? _userId;
  String? _userType;

  String? get userId => _userId;
  String? get userType => _userType;
  bool get isGuest => _userType == 'guest';

  /// 初始化用户（如果不存在则创建游客账户）
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    _userId = prefs.getString(_userIdKey);
    _userType = prefs.getString(_userTypeKey);

    // 如果用户不存在，创建游客账户
    if (_userId == null || _userId!.isEmpty) {
      await _createGuestAccount();
    }

    debugPrint('👤 用户ID: $_userId (类型: $_userType)');
  }

  /// 创建游客账户
  Future<void> _createGuestAccount() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 生成唯一的游客ID：guest_时间戳_随机数
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    _userId = 'guest_${timestamp}_$random';
    _userType = 'guest';

    await prefs.setString(_userIdKey, _userId!);
    await prefs.setString(_userTypeKey, _userType!);

    debugPrint('✅ 已创建游客账户: $_userId');
  }

  /// 获取当前用户ID（如果不存在则创建）
  Future<String> getUserId() async {
    if (_userId == null || _userId!.isEmpty) {
      await initialize();
    }
    return _userId!;
  }

  /// 重置用户（创建新的游客账户）
  Future<void> resetUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_userTypeKey);
    
    _userId = null;
    _userType = null;
    
    await _createGuestAccount();
    debugPrint('🔄 已重置用户，新用户ID: $_userId');
  }
}

