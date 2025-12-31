import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class UdpEventService extends ChangeNotifier {
  static const int udpPort = 8888;
  RawDatagramSocket? _socket;
  RawDatagramSocket? _ackSocket; // 用于发送确认消息
  StreamSubscription<RawSocketEvent>? _subscription;
  String? _deviceIp;
  InternetAddress? _deviceAddress;

  final StreamController<String> _eventController = StreamController<String>.broadcast();
  Stream<String> get events => _eventController.stream;

  void setDeviceIp(String ip) {
    _deviceIp = ip;
    try {
      _deviceAddress = InternetAddress(ip);
    } catch (e) {
      debugPrint('Invalid device IP: $ip');
    }
  }

  /// 发送UDP确认消息给设备（快速，不阻塞）
  void sendAck(String eventType) {
    if (_deviceAddress == null || _deviceIp == null) {
      debugPrint('⚠️ Cannot send ACK: device IP not set');
      return;
    }

    // 异步初始化socket（如果未初始化）
    if (_ackSocket == null) {
      RawDatagramSocket.bind(InternetAddress.anyIPv4, 0).then((socket) {
        _ackSocket = socket;
        _sendAckMessage(eventType);
      }).catchError((e) {
        debugPrint('Error initializing ACK socket: $e');
      });
      return;
    }

    _sendAckMessage(eventType);
  }

  /// 实际发送确认消息
  void _sendAckMessage(String eventType) {
    try {
      final ackMessage = 'ACK:$eventType';
      final messageBytes = ackMessage.codeUnits;
      _ackSocket!.send(messageBytes, _deviceAddress!, udpPort);
      debugPrint('✅ Sent ACK: $ackMessage to $_deviceIp');
    } catch (e) {
      debugPrint('Error sending ACK: $e');
    }
  }

  Future<void> startListening() async {
    if (_socket != null) return;

    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, udpPort);
      debugPrint('UDP event listener started on port $udpPort');

      _subscription = _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            final message = String.fromCharCodes(datagram.data);
            debugPrint('Received UDP event: $message from ${datagram.address}');

            // Only process events from the known device IP
            if (_deviceIp != null && datagram.address.address == _deviceIp) {
              _processEvent(message);
            } else if (_deviceIp == null) {
              // If device IP not set, accept from any source
              _processEvent(message);
            }
          }
        }
      });
    } catch (e) {
      debugPrint('UDP listener error: $e');
    }
  }

  void _processEvent(String message) {
    if (message == 'EVENT:VGA_READY') {
      _eventController.add('VGA_READY');
      // 发送确认消息
      sendAck('VGA_READY');
      notifyListeners();
    } else if (message == 'EVENT:HD_READY') {
      _eventController.add('HD_READY');
      // 发送确认消息
      sendAck('HD_READY');
      notifyListeners();
    }
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _socket?.close();
    _socket = null;
    _ackSocket?.close();
    _ackSocket = null;
    debugPrint('UDP event listener stopped');
  }

  @override
  void dispose() {
    stopListening();
    _eventController.close();
    super.dispose();
  }
}

