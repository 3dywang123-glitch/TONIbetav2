import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:async';

class HttpClientService {
  Future<bool> triggerCapture(String deviceIp) async {
    // 重试最多3次
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await http.get(
          Uri.parse('http://$deviceIp/trigger'),
          headers: {'Connection': 'close'},
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          debugPrint('Capture triggered successfully');
          return true;
        } else {
          debugPrint('Trigger failed: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Trigger error (attempt ${attempt + 1}/3): $e');
      }
      
      // 如果不是最后一次尝试，等待后重试
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 500));
      }
    }
    return false;
  }

  Future<Uint8List?> fetchVgaImage(String deviceIp) async {
    return _fetchImageWithRetry(deviceIp, '/latest_vga', 'VGA', maxRetries: 3);
  }

  Future<Uint8List?> fetchHdImage(String deviceIp) async {
    return _fetchImageWithRetry(deviceIp, '/latest_hd', 'HD', maxRetries: 3);
  }

  /// 带重试的图像获取，并在成功后发送确认
  Future<Uint8List?> _fetchImageWithRetry(
    String deviceIp,
    String endpoint,
    String imageType, {
    int maxRetries = 3,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final response = await http.get(
          Uri.parse('http://$deviceIp$endpoint'),
          headers: {'Connection': 'close'},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final imageData = response.bodyBytes;
          debugPrint('$imageType image fetched: ${imageData.length} bytes');
          
          // 发送确认消息（异步，不阻塞）
          _sendImageAck(deviceIp, endpoint);
          
          return imageData;
        } else if (response.statusCode == 404) {
          // 图像未就绪，等待后重试
          if (attempt < maxRetries - 1) {
            debugPrint('$imageType image not ready, retrying... (${attempt + 1}/$maxRetries)');
            await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
            continue;
          }
        } else {
          debugPrint('$imageType fetch failed: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('$imageType fetch error (attempt ${attempt + 1}/$maxRetries): $e');
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
      }
    }
    return null;
  }

  /// 发送图像接收确认（异步，不阻塞主流程）
  Future<void> _sendImageAck(String deviceIp, String endpoint) async {
    // 异步发送确认，不等待结果，确保不阻塞主流程
    unawaited(_sendImageAckSync(deviceIp, endpoint));
  }

  /// 实际发送确认的内部方法
  Future<void> _sendImageAckSync(String deviceIp, String endpoint) async {
    try {
      // 根据endpoint确定图像类型
      final imageType = endpoint.contains('vga') ? 'VGA' : 'HD';
      final ackEndpoint = '/ack_image?type=$imageType';
      
      final response = await http.get(
        Uri.parse('http://$deviceIp$ackEndpoint'),
        headers: {'Connection': 'close'},
      ).timeout(const Duration(milliseconds: 500)); // 超时时间缩短到500ms

      if (response.statusCode == 200) {
        debugPrint('✅ Image ACK sent: $imageType');
      }
    } catch (e) {
      // 确认失败不影响主流程，只记录日志
      debugPrint('⚠️ Failed to send image ACK: $e');
    }
  }


  /// Trigger burst capture (additional images after first HD) with retry
  Future<bool> triggerBurst(String deviceIp, int count) async {
    // 重试最多3次
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await http.get(
          Uri.parse('http://$deviceIp/burst?count=$count'),
          headers: {'Connection': 'close'},
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          debugPrint('Burst triggered: $count images');
          return true;
        } else {
          debugPrint('Burst trigger failed: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Burst trigger error (attempt ${attempt + 1}/3): $e');
      }
      
      // 如果不是最后一次尝试，等待后重试
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 500));
      }
    }
    return false;
  }
}

