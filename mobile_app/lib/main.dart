import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/network/device_discovery_service.dart';
import 'services/network/udp_event_service.dart';
import 'services/image/image_cache_service.dart';
import 'services/audio/vad_service.dart';
import 'services/audio/speech_recognition_service.dart';
import 'services/audio/offline_asr_service.dart';
import 'services/audio/offline_tts_service.dart';
import 'services/ai/ai_service.dart';
import 'services/database/local_database.dart';
import 'services/database/sync_service.dart';
import 'services/database/background_sync.dart';
import 'services/user/user_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化用户服务（自动创建游客账户）
  try {
    await UserService().initialize();
    debugPrint('✅ 用户服务初始化成功');
  } catch (e) {
    debugPrint('❌ 用户服务初始化失败: $e');
  }
  
  // 初始化本地数据库
  try {
    await LocalDatabase().database;
    debugPrint('✅ 本地数据库初始化成功');
  } catch (e) {
    debugPrint('❌ 本地数据库初始化失败: $e');
  }
  
  // 初始化同步服务
  try {
    await SyncService().initialize();
    debugPrint('✅ 同步服务初始化成功');
  } catch (e) {
    debugPrint('⚠️ 同步服务初始化失败: $e');
  }
  
  // 初始化离线语音服务（带错误处理）
  try {
    await OfflineAsrService().init();
  } catch (e) {
    debugPrint('⚠️ 离线ASR初始化失败: $e');
  }
  
  try {
    await OfflineTtsService().init();
  } catch (e) {
    debugPrint('⚠️ 离线TTS初始化失败: $e');
  }
  
  // 启动后台同步管理器
  BackgroundSyncManager().start();
  
  runApp(const ToniApp());
}

class ToniApp extends StatelessWidget {
  const ToniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceDiscoveryService()),
        ChangeNotifierProvider(create: (_) => UdpEventService()),
        ChangeNotifierProvider(create: (_) => ImageCacheService()),
        ChangeNotifierProvider(create: (_) => VadService()),
        ChangeNotifierProvider(create: (_) => SpeechRecognitionService()),
        ChangeNotifierProvider(create: (_) => AiService()),
      ],
      child: MaterialApp(
        title: 'T.O.N.I. Tactical Interface',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF050505),
          primaryColor: Colors.cyanAccent,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.cyanAccent,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

