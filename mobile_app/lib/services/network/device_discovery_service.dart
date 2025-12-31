import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../models/device_discovery.dart';

class DeviceDiscoveryService extends ChangeNotifier {
  static const String discoveryMessage = 'WHO_IS_TONI?';
  static const int udpPort = 8888;
  static const String bleDeviceName = 'TONI_PROV';
  static const String bleServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String bleCharacteristicUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';

  DeviceConnectionState _state = DeviceConnectionState.disconnected;
  DiscoveredDevice? _currentDevice;
  StreamSubscription? _bleScanSubscription;
  bool _isScanning = false;

  DeviceConnectionState get state => _state;
  DiscoveredDevice? get currentDevice => _currentDevice;
  bool get isScanning => _isScanning;

  Future<void> startDiscovery() async {
    if (_state == DeviceConnectionState.discovering) return;

    _state = DeviceConnectionState.discovering;
    notifyListeners();

    try {
      await _broadcastUdp();
    } catch (e) {
      debugPrint('UDP discovery error: $e');
      _state = DeviceConnectionState.disconnected;
      notifyListeners();
    }
  }

  Future<void> _broadcastUdp() async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;

    final message = discoveryMessage.codeUnits;
    final broadcastAddress = InternetAddress('255.255.255.255');

    socket.send(message, broadcastAddress, udpPort);
    debugPrint('Sent UDP broadcast: $discoveryMessage');

    socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();
        if (datagram != null) {
          final response = String.fromCharCodes(datagram.data);
          debugPrint('Received UDP response: $response');
          _parseDiscoveryResponse(response, datagram.address);
        }
      }
    });

    // Stop listening after 5 seconds
    Timer(const Duration(seconds: 5), () {
      socket.close();
      if (_state == DeviceConnectionState.discovering) {
        _state = DeviceConnectionState.disconnected;
        notifyListeners();
      }
    });
  }

  void _parseDiscoveryResponse(String response, InternetAddress address) {
    if (response.startsWith('I_AM_TONI,')) {
      final parts = response.substring(10).split(',');
      String? ssid;
      String? ip;

      for (final part in parts) {
        if (part.startsWith('SSID=')) {
          ssid = part.substring(5);
        } else if (part.startsWith('IP=')) {
          ip = part.substring(3);
        }
      }

      if (ip != null) {
        _currentDevice = DiscoveredDevice(
          ip: ip,
          ssid: ssid ?? 'Unknown',
          discoveredAt: DateTime.now(),
        );
        _state = DeviceConnectionState.connected;
        notifyListeners();
        debugPrint('Device discovered: $_currentDevice');
      }
    }
  }

  Future<void> startBleScan() async {
    if (_isScanning) return;

    _isScanning = true;
    _state = DeviceConnectionState.provisioning;
    notifyListeners();

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withNames: [bleDeviceName],
      );

      _bleScanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          if (result.device.platformName == bleDeviceName ||
              result.device.advName == bleDeviceName) {
            _provisionDeviceConnection(result.device);
            break;
          }
        }
      });
    } catch (e) {
      debugPrint('BLE scan error: $e');
      _isScanning = false;
      _state = DeviceConnectionState.disconnected;
      notifyListeners();
    }
  }

  Future<void> stopBleScan() async {
    await FlutterBluePlus.stopScan();
    await _bleScanSubscription?.cancel();
    _bleScanSubscription = null;
    _isScanning = false;
    _state = DeviceConnectionState.disconnected;
    notifyListeners();
  }

  BluetoothCharacteristic? _provisionCharacteristic;
  BluetoothDevice? _provisionDevice;

  Future<void> _provisionDeviceConnection(BluetoothDevice device) async {
    try {
      await device.connect();
      debugPrint('Connected to BLE device: ${device.platformName}');

      final services = await device.discoverServices();
      final targetService = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase() == bleServiceUuid.toLowerCase(),
        orElse: () => throw Exception('Service not found'),
      );

      final characteristic = targetService.characteristics.firstWhere(
        (c) => c.uuid.toString().toLowerCase() == bleCharacteristicUuid.toLowerCase(),
        orElse: () => throw Exception('Characteristic not found'),
      );

      // Store characteristic for later use
      _provisionCharacteristic = characteristic;
      _provisionDevice = device;

      notifyListeners();
    } catch (e) {
      debugPrint('BLE provision error: $e');
      await device.disconnect();
      _isScanning = false;
      _state = DeviceConnectionState.disconnected;
      notifyListeners();
    }
  }

  Future<void> writeWiFiCredentials(String ssid, String password) async {
    if (_provisionCharacteristic == null) {
      throw Exception('Device not provisioned');
    }

    final credentials = '$ssid,$password';
    await _provisionCharacteristic!.write(
      credentials.codeUnits,
      withoutResponse: false,
    );

    debugPrint('WiFi credentials written: $ssid');
    await _provisionDevice?.disconnect();
    _provisionCharacteristic = null;
    _provisionDevice = null;
    _isScanning = false;
    _state = DeviceConnectionState.disconnected;
    notifyListeners();
  }

  void disconnect() {
    _currentDevice = null;
    _state = DeviceConnectionState.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    stopBleScan();
    super.dispose();
  }
}

