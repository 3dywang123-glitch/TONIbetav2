import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../database/local_database.dart';
import '../image/image_cache_service.dart';

class CacheCleanupService {
  static final CacheCleanupService _instance = CacheCleanupService._internal();
  factory CacheCleanupService() => _instance;
  CacheCleanupService._internal();

  /// 清理所有缓存
  /// [clearUserData] - 是否清除用户数据（会话、消息等）
  /// [clearImages] - 是否清除图像缓存
  /// [clearTempFiles] - 是否清除临时文件
  /// [clearSettings] - 是否清除设置（保留后端URL和秘书风格）
  Future<Map<String, dynamic>> clearAllCache({
    bool clearUserData = true,
    bool clearImages = true,
    bool clearTempFiles = true,
    bool clearSettings = false,
  }) async {
    final results = <String, dynamic>{
      'userData': false,
      'images': false,
      'tempFiles': false,
      'settings': false,
      'totalSizeFreed': 0,
    };

    try {
      // 1. 清理用户数据（本地数据库）
      if (clearUserData) {
        try {
          final db = LocalDatabase();
          final dbSize = await db.getDatabaseSize();
          await db.clearAllData();
          results['userData'] = true;
          results['totalSizeFreed'] = (results['totalSizeFreed'] as int) + dbSize;
          debugPrint('✅ 已清理用户数据: ${_formatBytes(dbSize)}');
        } catch (e) {
          debugPrint('❌ 清理用户数据失败: $e');
        }
      }

      // 2. 清理图像缓存
      if (clearImages) {
        try {
          final imageCache = ImageCacheService();
          imageCache.clearCache();
          results['images'] = true;
          debugPrint('✅ 已清理图像缓存');
        } catch (e) {
          debugPrint('❌ 清理图像缓存失败: $e');
        }
      }

      // 3. 清理临时文件
      if (clearTempFiles) {
        try {
          final tempDir = await getTemporaryDirectory();
          final tempSize = await _clearDirectory(tempDir);
          results['tempFiles'] = true;
          results['totalSizeFreed'] = (results['totalSizeFreed'] as int) + tempSize;
          debugPrint('✅ 已清理临时文件: ${_formatBytes(tempSize)}');
        } catch (e) {
          debugPrint('❌ 清理临时文件失败: $e');
        }
      }

      // 4. 清理设置（可选，保留重要设置）
      if (clearSettings) {
        try {
          final prefs = await SharedPreferences.getInstance();
          // 保留后端URL和秘书风格
          final backendUrl = prefs.getString('backend_url');
          final secretaryStyle = prefs.getString('secretary_style');
          
          await prefs.clear();
          
          // 恢复重要设置
          if (backendUrl != null) {
            await prefs.setString('backend_url', backendUrl);
          }
          if (secretaryStyle != null) {
            await prefs.setString('secretary_style', secretaryStyle);
          }
          
          results['settings'] = true;
          debugPrint('✅ 已清理设置（保留重要配置）');
        } catch (e) {
          debugPrint('❌ 清理设置失败: $e');
        }
      }

      debugPrint('🎉 缓存清理完成，释放空间: ${_formatBytes(results['totalSizeFreed'] as int)}');
    } catch (e) {
      debugPrint('❌ 缓存清理过程出错: $e');
    }

    return results;
  }

  /// 清理指定目录下的所有文件
  Future<int> _clearDirectory(Directory dir) async {
    int totalSize = 0;
    
    try {
      if (!await dir.exists()) {
        return 0;
      }

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          try {
            final size = await entity.length();
            await entity.delete();
            totalSize += size;
          } catch (e) {
            debugPrint('删除文件失败: ${entity.path} - $e');
          }
        }
      }
    } catch (e) {
      debugPrint('清理目录失败: ${dir.path} - $e');
    }

    return totalSize;
  }

  /// 格式化字节数为可读格式
  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  /// 获取缓存大小统计
  Future<Map<String, int>> getCacheSize() async {
    final sizes = <String, int>{
      'database': 0,
      'tempFiles': 0,
      'total': 0,
    };

    try {
      // 数据库大小
      final db = LocalDatabase();
      sizes['database'] = await db.getDatabaseSize();

      // 临时文件大小
      final tempDir = await getTemporaryDirectory();
      sizes['tempFiles'] = await _getDirectorySize(tempDir);

      sizes['total'] = sizes['database']! + sizes['tempFiles']!;
    } catch (e) {
      debugPrint('获取缓存大小失败: $e');
    }

    return sizes;
  }

  /// 获取目录大小
  Future<int> _getDirectorySize(Directory dir) async {
    int totalSize = 0;
    
    try {
      if (!await dir.exists()) {
        return 0;
      }

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          try {
            totalSize += await entity.length();
          } catch (e) {
            // 忽略无法访问的文件
          }
        }
      }
    } catch (e) {
      debugPrint('获取目录大小失败: ${dir.path} - $e');
    }

    return totalSize;
  }
}

