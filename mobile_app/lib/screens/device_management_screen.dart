import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/network/device_discovery_service.dart';
import '../services/ai/ai_service.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = false;
  String? _error;
  final TextEditingController _manualIpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  @override
  void dispose() {
    _manualIpController.dispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final aiService = context.read<AiService>();
      final backendUrl = aiService.backendUrl;
      
      if (backendUrl == null || backendUrl.isEmpty) {
        setState(() {
          _error = '后端服务未配置';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('$backendUrl/api/devices'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _devices = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = '加载失败: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addManualDevice(String ip) async {
    if (ip.isEmpty) return;

    try {
      final aiService = context.read<AiService>();
      final backendUrl = aiService.backendUrl;
      
      if (backendUrl == null || backendUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('后端服务未配置')),
        );
        return;
      }

      final response = await http.post(
        Uri.parse('$backendUrl/api/devices'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_ip': ip,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备已添加')),
        );
        _manualIpController.clear();
        _loadDevices();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final discoveryService = context.watch<DeviceDiscoveryService>();
    final currentDevice = discoveryService.currentDevice;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: const Text('设备管理'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDevices,
          ),
        ],
      ),
      body: Column(
        children: [
          // 当前连接的设备
          if (currentDevice != null)
            Card(
              color: Colors.grey[900]!.withOpacity(0.5),
              margin: const EdgeInsets.all(16),
              child: ListTile(
                leading: const Icon(Icons.devices, color: Colors.cyanAccent),
                title: const Text('当前设备', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  '${currentDevice.ssid}\n${currentDevice.ip}',
                  style: const TextStyle(color: Colors.white54),
                ),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              ),
            ),
          
          // 手动添加设备
          Card(
            color: Colors.grey[900]!.withOpacity(0.5),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '手动添加设备',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _manualIpController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: '设备IP地址',
                      labelStyle: const TextStyle(color: Colors.white54),
                      hintText: '192.168.1.100',
                      hintStyle: const TextStyle(color: Colors.white38),
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.cyanAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _addManualDevice(_manualIpController.text);
                    },
                    child: const Text('添加设备'),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '已注册设备',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          
          // 设备列表
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadDevices,
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      )
                    : _devices.isEmpty
                        ? const Center(
                            child: Text(
                              '暂无已注册设备',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadDevices,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _devices.length,
                              itemBuilder: (context, index) {
                                final device = _devices[index];
                                return _buildDeviceCard(device);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    final deviceIp = device['device_ip'] ?? 'Unknown';
    final deviceSsid = device['device_ssid'] ?? 'Unknown';
    final lastSeen = device['last_seen'] != null
        ? DateTime.parse(device['last_seen'])
        : null;

    return Card(
      color: Colors.grey[900]!.withOpacity(0.5),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.cyanAccent.withOpacity(0.2),
          child: const Icon(Icons.devices, color: Colors.cyanAccent, size: 20),
        ),
        title: Text(
          deviceSsid,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IP: $deviceIp',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            if (lastSeen != null)
              Text(
                '最后在线: ${_formatTime(lastSeen)}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}小时前';
    } else {
      return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

