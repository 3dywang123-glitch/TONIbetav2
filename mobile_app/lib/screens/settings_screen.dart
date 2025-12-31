import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/network/device_discovery_service.dart';
import '../services/ai/ai_service.dart';
import '../services/database/sync_service.dart';
import '../services/cache/cache_cleanup_service.dart';
import '../services/user/user_service.dart';
import 'provisioning_screen.dart';
import 'history_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _backendUrlController = TextEditingController();
  String _selectedSecretaryStyle = 'cute';
  bool _isLoading = false;
  String? _userId;
  String _cacheSize = '计算中...';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserInfo();
    _loadCacheSize();
  }

  Future<void> _loadUserInfo() async {
    final userService = UserService();
    await userService.initialize();
    setState(() {
      _userId = userService.userId;
    });
  }

  Future<void> _loadCacheSize() async {
    final cleanupService = CacheCleanupService();
    final sizes = await cleanupService.getCacheSize();
    setState(() {
      _cacheSize = _formatBytes(sizes['total'] ?? 0);
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final backendUrl = prefs.getString('backend_url') ?? '';
    final secretaryStyle = prefs.getString('secretary_style') ?? 'cute';
    
    setState(() {
      _backendUrlController.text = backendUrl;
      _selectedSecretaryStyle = secretaryStyle;
    });

    // Initialize AI service with saved URL
    if (backendUrl.isNotEmpty) {
      final aiService = context.read<AiService>();
      await aiService.initialize(backendUrl: backendUrl);
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('backend_url', _backendUrlController.text);
      await prefs.setString('secretary_style', _selectedSecretaryStyle);

      final aiService = context.read<AiService>();
      await aiService.initialize(
        backendUrl: _backendUrlController.text.isEmpty
            ? null
            : _backendUrlController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置已保存')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discoveryService = context.watch<DeviceDiscoveryService>();

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 会话历史入口
          Card(
            color: Colors.grey[900]!.withOpacity(0.5),
            child: ListTile(
              leading: const Icon(Icons.history, color: Colors.cyanAccent),
              title: const Text('会话历史', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HistoryScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.grey[900]!.withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '设备发现',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      discoveryService.startDiscovery();
                    },
                    child: const Text('搜索设备'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.grey[900]!.withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '蓝牙配网',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '当设备无法连接WiFi时，使用蓝牙进行配网',
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProvisioningScreen(),
                        ),
                      );
                    },
                    child: const Text('开始配网'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.grey[900]!.withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '后端服务',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _backendUrlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: '后端API地址',
                      labelStyle: const TextStyle(color: Colors.white54),
                      hintText: 'http://localhost:3000',
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
                    onPressed: _isLoading ? null : _saveSettings,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('保存'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.grey[900]!.withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '秘书风格',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSecretaryStyle,
                    dropdownColor: Colors.grey[900],
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.cyanAccent),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cute', child: Text('元气 (Cute)')),
                      DropdownMenuItem(value: 'cold', child: Text('冰冷 (Cold)')),
                      DropdownMenuItem(value: 'funny', child: Text('幽默 (Funny)')),
                      DropdownMenuItem(value: 'tsundere', child: Text('傲娇 (Tsundere)')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedSecretaryStyle = value;
                        });
                        _saveSettings();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.grey[900]!.withOpacity(0.5),
            child: ListTile(
              leading: const Icon(Icons.sync, color: Colors.cyanAccent),
              title: const Text('立即同步', style: TextStyle(color: Colors.white)),
              subtitle: const Text('立即同步本地数据到服务器', style: TextStyle(color: Colors.white54)),
              onTap: () async {
                final syncService = SyncService();
                await syncService.initialize();
                await syncService.syncNow();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('同步完成')),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          // 用户信息卡片
          Card(
            color: Colors.grey[900]!.withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '账户信息',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, color: Colors.cyanAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '游客账户',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            Text(
                              _userId ?? '加载中...',
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 缓存信息卡片
          Card(
            color: Colors.grey[900]!.withOpacity(0.5),
            child: ListTile(
              leading: const Icon(Icons.storage, color: Colors.cyanAccent),
              title: const Text('缓存大小', style: TextStyle(color: Colors.white)),
              subtitle: Text('当前缓存: $_cacheSize', style: const TextStyle(color: Colors.white54)),
              trailing: IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                onPressed: _loadCacheSize,
                tooltip: '刷新',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.grey[900]!.withOpacity(0.5),
            child: ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('清除缓存', style: TextStyle(color: Colors.white)),
              subtitle: const Text('清除所有本地缓存数据（会话、消息、图像等）', style: TextStyle(color: Colors.white54)),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('确认清除缓存'),
                    content: const Text(
                      '确定要清除所有本地缓存数据吗？\n\n'
                      '这将删除：\n'
                      '• 所有会话和消息\n'
                      '• 图像缓存\n'
                      '• 临时文件\n\n'
                      '此操作不可恢复！',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('确定清除', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && mounted) {
                  // 显示加载提示
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );

                  try {
                    final cleanupService = CacheCleanupService();
                    final results = await cleanupService.clearAllCache(
                      clearUserData: true,
                      clearImages: true,
                      clearTempFiles: true,
                      clearSettings: false, // 保留设置
                    );

                    if (mounted) {
                      Navigator.pop(context); // 关闭加载对话框
                      
                      // 刷新缓存大小
                      await _loadCacheSize();
                      
                      final sizeFreed = _formatBytes(results['totalSizeFreed'] as int);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('缓存已清除，释放空间: $sizeFreed'),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context); // 关闭加载对话框
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('清除缓存失败: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

