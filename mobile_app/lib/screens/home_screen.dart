import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/network/device_discovery_service.dart';
import '../services/network/udp_event_service.dart';
import '../services/network/http_client_service.dart';
import '../services/image/image_cache_service.dart';
import '../services/audio/vad_service.dart';
import '../services/audio/speech_recognition_service.dart';
import '../services/audio/offline_asr_service.dart';
import '../services/audio/offline_tts_service.dart';
import '../services/ai/ai_service.dart';
import '../models/capture_state.dart';
import '../models/chat_message.dart';
import '../widgets/device_status_widget.dart';
import '../widgets/capture_button_widget.dart';
import 'settings_screen.dart';
import 'history_screen.dart';
import 'image_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HttpClientService _httpClient = HttpClientService();
  final OfflineAsrService _offlineAsr = OfflineAsrService();
  final ScrollController _scrollController = ScrollController();
  CaptureState _captureState = CaptureState.idle;
  CaptureSession? _currentSession;
  String _currentSpeech = '';
  StreamSubscription<String>? _asrSubscription;
  final List<ChatMessage> _messages = [];
  String? _errorMessage;
  bool _offlineAsrReady = false;
  bool _offlineTtsReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
    
    // 监听离线ASR实时识别结果
    _asrSubscription = _offlineAsr.onTextUpdated.listen((text) {
      if (mounted) {
        setState(() {
          _currentSpeech = text;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _asrSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _addMessage(ChatMessage message) {
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _initializeServices() async {
    if (!mounted) return;
    
    final discovery = context.read<DeviceDiscoveryService>();
    final udpEvents = context.read<UdpEventService>();
    final aiService = context.read<AiService>();

    // 检查离线服务状态
    final offlineTts = OfflineTtsService();
    setState(() {
      _offlineAsrReady = _offlineAsr.isReady;
      _offlineTtsReady = offlineTts.isReady;
    });

    // Start device discovery
    await discovery.startDiscovery();

    // Setup UDP event listener
    if (discovery.currentDevice != null) {
      udpEvents.setDeviceIp(discovery.currentDevice!.ip);
      await udpEvents.startListening();
      _setupEventHandlers(udpEvents);
    }

    // Initialize AI service
    await aiService.initialize();

    // Listen to discovery changes
    discovery.addListener(() {
      if (discovery.currentDevice != null && mounted) {
        udpEvents.setDeviceIp(discovery.currentDevice!.ip);
        udpEvents.startListening();
        _setupEventHandlers(udpEvents);
      }
    });
  }

  void _setupEventHandlers(UdpEventService udpEvents) {
    udpEvents.events.listen((event) async {
      if (event == 'VGA_READY') {
        await _handleVgaReady();
      } else if (event == 'HD_READY') {
        await _handleHdReady();
      }
    });
  }

  Future<void> _handleVgaReady() async {
    final discovery = context.read<DeviceDiscoveryService>();
    final imageCache = context.read<ImageCacheService>();

    if (discovery.currentDevice == null) return;

    setState(() {
      _captureState = CaptureState.vgaReady;
    });

    // 如果UDP事件丢失，等待一段时间后主动获取（超时保护）
    final imageData = await _fetchVgaWithTimeout(discovery.currentDevice!.ip);
    if (imageData != null) {
      await imageCache.setCacheA(imageData);
      // 图像已确认接收（在_fetchImageWithRetry中已发送确认）
      await _processSecretaryAi();
    } else {
      if (mounted) {
        setState(() {
          _errorMessage = '获取VGA图像失败，请重试';
          _captureState = CaptureState.error;
        });
      }
    }
  }

  /// 获取VGA图像（带超时保护，即使UDP事件丢失也能获取）
  Future<Uint8List?> _fetchVgaWithTimeout(String deviceIp) async {
    // 先尝试立即获取（如果UDP事件已收到）
    var imageData = await _httpClient.fetchVgaImage(deviceIp);
    if (imageData != null) return imageData;

    // 如果立即获取失败，等待UDP事件（最多等待2秒）
    final completer = Completer<Uint8List?>();
    StreamSubscription? subscription;
    Timer? timeoutTimer;

    subscription = context.read<UdpEventService>().events.listen((event) async {
      if (event == 'VGA_READY') {
        final data = await _httpClient.fetchVgaImage(deviceIp);
        if (data != null && !completer.isCompleted) {
          subscription?.cancel();
          timeoutTimer?.cancel();
          completer.complete(data);
        }
      }
    });

    // 超时后主动获取（UDP事件可能丢失）
    timeoutTimer = Timer(const Duration(seconds: 2), () async {
      if (!completer.isCompleted) {
        subscription?.cancel();
        debugPrint('⚠️ UDP事件超时，主动获取VGA图像');
        final data = await _httpClient.fetchVgaImage(deviceIp);
        completer.complete(data);
      }
    });

    return await completer.future;
  }

  Future<void> _handleHdReady() async {
    final discovery = context.read<DeviceDiscoveryService>();
    final imageCache = context.read<ImageCacheService>();
    final aiService = context.read<AiService>();

    if (discovery.currentDevice == null) return;

    setState(() {
      _captureState = CaptureState.hdReady;
    });

    // 如果UDP事件丢失，等待一段时间后主动获取（超时保护）
    final imageData = await _fetchHdWithTimeout(discovery.currentDevice!.ip);
    if (imageData != null) {
      await imageCache.setCacheB(imageData);
      // 图像已确认接收（在_fetchImageWithRetry中已发送确认）
      
      // 检查是否需要连拍
      final burstCount = _currentSession?.burstCount ?? aiService.burstCount;
      
      if (burstCount > 0 && _currentSession != null) {
        // 开始连拍流程（第一张HD图已获取，还需burstCount-1张）
        setState(() {
          _captureState = CaptureState.bursting;
        });
        await _waitForBurstImages(discovery.currentDevice!.ip, burstCount - 1);
      } else {
        // 直接调用专家AI
        await _processExpertAi();
      }
    } else {
      if (mounted) {
        setState(() {
          _errorMessage = '获取HD图像失败，请重试';
          _captureState = CaptureState.error;
        });
      }
    }
  }

  /// 获取HD图像（带超时保护，即使UDP事件丢失也能获取）
  Future<Uint8List?> _fetchHdWithTimeout(String deviceIp) async {
    // 先尝试立即获取（如果UDP事件已收到）
    var imageData = await _httpClient.fetchHdImage(deviceIp);
    if (imageData != null) return imageData;

    // 如果立即获取失败，等待UDP事件（最多等待3秒，因为HD图在T+3.0s才拍摄）
    final completer = Completer<Uint8List?>();
    StreamSubscription? subscription;
    Timer? timeoutTimer;

    subscription = context.read<UdpEventService>().events.listen((event) async {
      if (event == 'HD_READY') {
        final data = await _httpClient.fetchHdImage(deviceIp);
        if (data != null && !completer.isCompleted) {
          subscription?.cancel();
          timeoutTimer?.cancel();
          completer.complete(data);
        }
      }
    });

    // 超时后主动获取（UDP事件可能丢失）
    timeoutTimer = Timer(const Duration(seconds: 3), () async {
      if (!completer.isCompleted) {
        subscription?.cancel();
        debugPrint('⚠️ UDP事件超时，主动获取HD图像');
        final data = await _httpClient.fetchHdImage(deviceIp);
        completer.complete(data);
      }
    });

    return await completer.future;
  }

  Future<void> _processSecretaryAi() async {
    final imageCache = context.read<ImageCacheService>();
    final speechRecognition = context.read<SpeechRecognitionService>();
    final aiService = context.read<AiService>();

    if (imageCache.cacheA == null) return;

    setState(() {
      _captureState = CaptureState.processingSecretary;
    });

    // 优先使用离线ASR的结果
    String firstCommand = _offlineAsr.currentText.isNotEmpty
        ? _offlineAsr.currentText
        : (speechRecognition.firstCommand.isNotEmpty
            ? speechRecognition.firstCommand
            : '');

    // 检测用户是否没有说话（使用默认文本）
    final bool hasNoSpeech = firstCommand.isEmpty || 
        firstCommand.trim().isEmpty ||
        firstCommand == '帮我看下这个';

    // 如果没有语音输入，使用默认表达
    if (hasNoSpeech) {
      firstCommand = '帮我看下这个';
    }

    // 添加用户消息（带图像）
    if (firstCommand.isNotEmpty && _currentSession != null) {
      _addMessage(ChatMessage(
        id: '${_currentSession!.sessionId}_user_${DateTime.now().millisecondsSinceEpoch}',
        text: firstCommand,
        isUser: true,
        timestamp: DateTime.now(),
        sessionId: _currentSession!.sessionId,
        imageData: imageCache.cacheA,
      ));
    }

    // 获取秘书风格（从SharedPreferences）
    final prefs = await SharedPreferences.getInstance();
    final secretaryStyle = prefs.getString('secretary_style') ?? 'cute';

    // 传递会话ID和设备IP
    // 如果用户没有说话，在文本中明确说明
    final String textForAI = hasNoSpeech 
        ? '[用户没有说话，但按下了拍摄按钮，想让AI帮忙看看这张图片]'
        : firstCommand;

    final discovery = context.read<DeviceDiscoveryService>();
    final result = await aiService.callSecretaryAi(
      text: textForAI,
      imageData: imageCache.cacheA!,
      secretaryStyle: secretaryStyle,
      sessionId: _currentSession?.sessionId,
      deviceIp: discovery.currentDevice?.ip,
    );

    if (result != null && mounted) {
      final burstCount = (result['burst_count'] as int?) ?? 0;
      
      setState(() {
        if (_currentSession != null) {
          _currentSession!.secretaryReply = result['reply'];
          _currentSession!.expertType = result['expert'];
          _currentSession!.cameraAction = result['camera_action'];
          _currentSession!.burstCount = burstCount;
        }
      });

      // 添加秘书回复消息
      if (result['reply'] != null && _currentSession != null) {
        _addMessage(ChatMessage(
          id: '${_currentSession!.sessionId}_secretary_${DateTime.now().millisecondsSinceEpoch}',
          text: result['reply'] as String,
          isUser: false,
          isSecretary: true,
          timestamp: DateTime.now(),
          expertType: result['expert'] as String?,
          sessionId: _currentSession!.sessionId,
        ));
      }

      // 检查是否需要连拍
      if (burstCount > 0 && _currentSession != null) {
        // 等待HD图像就绪后开始连拍
        // 连拍将在_handleHdReady中触发
        debugPrint('📸 需要连拍 $burstCount 张');
      } else {
        // 不需要连拍，等待HD图像就绪后直接调用专家AI
        debugPrint('📸 单张拍摄模式');
      }
    }
  }

  Future<void> _processExpertAi() async {
    final imageCache = context.read<ImageCacheService>();
    final speechRecognition = context.read<SpeechRecognitionService>();
    final aiService = context.read<AiService>();

    if (imageCache.cacheB == null) return;

    setState(() {
      _captureState = CaptureState.processingExpert;
    });

    // 优先使用离线ASR的结果
    String userContext = _offlineAsr.currentText.isNotEmpty
        ? _offlineAsr.currentText
        : (speechRecognition.fullContext.isNotEmpty
            ? speechRecognition.fullContext
            : speechRecognition.firstCommand);

    final secretaryContext = aiService.secretaryReply ?? '';

    final picRequire = aiService.cameraAction ?? 'normal';
    
    // 获取图像数据（支持连拍）
    final List<Uint8List>? burstImages = imageCache.burstImages.isNotEmpty 
        ? imageCache.burstImages 
        : null;
    
    // 主图像选择逻辑：
    // - wide模式：使用未裁剪的原图（cacheB）
    // - normal模式：优先使用裁剪图（cacheC），如果没有则使用原图（cacheB）
    final imageData = picRequire == 'wide' && imageCache.cacheB != null
        ? imageCache.cacheB!  // 广角模式：使用原图
        : (imageCache.cacheC ?? imageCache.cacheB!);  // 正常模式：优先裁剪图

    try {
    // 传递会话ID和设备IP
    final discovery = context.read<DeviceDiscoveryService>();
    final reply = await aiService.callExpertAi(
      userContext: userContext,
      secretaryContext: secretaryContext,
      imageData: imageData,
      picRequire: picRequire,
      sessionId: _currentSession?.sessionId,
      deviceIp: discovery.currentDevice?.ip,
      burstImages: burstImages, // 传递连拍图像
    );

      if (reply != null && mounted) {
        setState(() {
          if (_currentSession != null) {
            _currentSession!.expertReply = reply;
          }
          _captureState = CaptureState.complete;
        });

        // 添加专家回复消息
        if (_currentSession != null) {
          _addMessage(ChatMessage(
            id: '${_currentSession!.sessionId}_expert_${DateTime.now().millisecondsSinceEpoch}',
            text: reply,
            isUser: false,
            isSecretary: false,
            timestamp: DateTime.now(),
            expertType: aiService.expertType,
            sessionId: _currentSession!.sessionId,
            imageData: imageData,
          ));
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = '专家AI处理失败: $error';
          _captureState = CaptureState.error;
        });
      }
    }
  }

  /// 等待连拍图像（第一张HD图已获取，还需等待剩余图像）
  Future<void> _waitForBurstImages(String deviceIp, int remainingCount) async {
    if (remainingCount <= 0) {
      // 不需要连拍，直接调用专家AI
      await _processExpertAi();
      return;
    }

    final imageCache = context.read<ImageCacheService>();
    final udpEvents = context.read<UdpEventService>();
    
    // 触发连拍（固件端需要实现 /burst 接口）
    final success = await _httpClient.triggerBurst(deviceIp, remainingCount);
    if (!success) {
      debugPrint('⚠️ 连拍触发失败，使用单张图像');
      await _processExpertAi();
      return;
    }

    // 监听HD_READY事件，收集连拍图像
    int receivedCount = 0;
    final completer = Completer<void>();
    StreamSubscription? subscription;
    Timer? timeoutTimer;

    subscription = udpEvents.events.listen((event) async {
      if (event == 'HD_READY') {
        final imageData = await _httpClient.fetchHdImage(deviceIp);
        if (imageData != null) {
          await imageCache.addBurstImage(imageData);
          receivedCount++;
          debugPrint('📸 收到连拍图像 ${receivedCount}/$remainingCount');
          
          if (receivedCount >= remainingCount) {
            subscription?.cancel();
            timeoutTimer?.cancel();
            if (!completer.isCompleted) {
              completer.complete();
            }
          }
        }
      }
    });

    // 超时保护（最多等待30秒）
    timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        subscription?.cancel();
        debugPrint('⚠️ 连拍超时，已收到 $receivedCount/$remainingCount 张图像');
        completer.complete();
      }
    });

    await completer.future;
    
    // 连拍完成，调用专家AI
    await _processExpertAi();
  }

  Future<void> _triggerCapture() async {
    final discovery = context.read<DeviceDiscoveryService>();
    final vadService = context.read<VadService>();
    final speechRecognition = context.read<SpeechRecognitionService>();
    final imageCache = context.read<ImageCacheService>();
    final aiService = context.read<AiService>();

    if (discovery.currentDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设备未连接')),
      );
      return;
    }

    // Reset state
    imageCache.clearCache();
    speechRecognition.reset();
    aiService.reset();
    _offlineAsr.reset();

    setState(() {
      _captureState = CaptureState.triggered;
      _currentSession = CaptureSession(
        sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: DateTime.now(),
        state: CaptureState.triggered,
      );
      _messages.clear();
    });

    // Start audio recording - 优先使用离线ASR
    if (_offlineAsr.isReady) {
      await _offlineAsr.startListening();
    } else {
      // 如果离线ASR未就绪，显示提示
      if (_offlineAsr.initError != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('离线语音识别不可用，使用在线识别: ${_offlineAsr.initError}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      await vadService.startRecording();
      await speechRecognition.startListening();
    }

    // Trigger device capture
    final success = await _httpClient.triggerCapture(discovery.currentDevice!.ip);
    if (!success) {
      setState(() {
        _captureState = CaptureState.error;
        _errorMessage = '设备拍摄失败，请检查设备连接';
      });
      if (_offlineAsr.isListening) {
        await _offlineAsr.stopListening();
      } else {
        await vadService.cancelRecording();
        await speechRecognition.stopListening();
      }
      return;
    }

    setState(() {
      _captureState = CaptureState.waitingVga;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          // 主内容区域
          Positioned.fill(
            child: Column(
              children: [
                // 顶部状态栏
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            DeviceStatusWidget(
                              discoveryService: context.watch<DeviceDiscoveryService>(),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.history, color: Colors.white54),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const HistoryScreen()),
                                    );
                                  },
                                ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.history, color: Colors.white54),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const HistoryScreen()),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings, color: Colors.white54),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                                );
                              },
                            ),
                          ],
                        ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // 错误提示横幅
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red, fontSize: 12),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _errorMessage = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      // 离线服务状态提示
                      if (!_offlineAsrReady || !_offlineTtsReady)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  !_offlineAsrReady && !_offlineTtsReady
                                      ? '离线语音服务未就绪，将使用在线服务'
                                      : (!_offlineAsrReady
                                          ? '离线语音识别未就绪'
                                          : '离线语音合成未就绪'),
                                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // 中间内容区域 - 聊天列表
                Expanded(
                  child: Stack(
                    children: [
                      // 消息列表
                      ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _messages.length + (_currentSpeech.isNotEmpty ? 1 : 0) + (_captureState != CaptureState.idle && _captureState != CaptureState.complete ? 1 : 0),
                        itemBuilder: (context, index) {
                          // 实时语音识别显示
                          if (index == 0 && _currentSpeech.isNotEmpty) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.cyanAccent.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                "🎤 $_currentSpeech",
                                style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          }

                          // 状态消息
                          if (index == (_currentSpeech.isNotEmpty ? 1 : 0) && 
                              _captureState != CaptureState.idle && 
                              _captureState != CaptureState.complete) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white10.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getStatusText(),
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          // 消息气泡
                          final messageIndex = index - (_currentSpeech.isNotEmpty ? 1 : 0) - 
                                             (_captureState != CaptureState.idle && _captureState != CaptureState.complete ? 1 : 0);
                          if (messageIndex >= 0 && messageIndex < _messages.length) {
                            return _buildChatMessage(_messages[messageIndex]);
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      // 底部拍摄按钮（浮动）
                      if (_captureState == CaptureState.idle || _captureState == CaptureState.complete)
                        Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: CaptureButtonWidget(
                              state: _captureState,
                              onPressed: _triggerCapture,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildChatMessage(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white10,
              child: Icon(
                message.isSecretary ? Icons.smart_toy : Icons.psychology,
                size: 18,
                color: Colors.cyanAccent,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? Colors.cyanAccent.withOpacity(0.2)
                        : Colors.grey[900]!.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: message.isUser
                          ? Colors.cyanAccent.withOpacity(0.3)
                          : Colors.white10,
                    ),
                  ),
                  child: GestureDetector(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 图像缩略图
                        if (message.imageData != null) ...[
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ImagePreviewScreen(
                                    imageData: message.imageData!,
                                    title: message.text,
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                message.imageData!,
                                width: 200,
                                height: 150,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        // 文本内容
                        Text(
                          message.text,
                          style: TextStyle(
                            color: message.isUser ? Colors.cyanAccent : Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (message.isUser) const SizedBox(width: 8),
        ],
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
      return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  String _getStatusText() {
    switch (_captureState) {
      case CaptureState.idle:
        return '准备就绪';
      case CaptureState.triggered:
        return '已触发拍摄...';
      case CaptureState.waitingVga:
        return '等待VGA图像...';
      case CaptureState.vgaReady:
        return 'VGA图像就绪';
      case CaptureState.waitingHd:
        return '等待HD图像...';
      case CaptureState.hdReady:
        return 'HD图像就绪';
      case CaptureState.processingSecretary:
        return '处理中（秘书AI）...';
      case CaptureState.bursting:
        final current = _currentSession?.currentBurstIndex ?? 0;
        final total = _currentSession?.burstCount ?? 0;
        return '连拍中 ($current/$total)...';
      case CaptureState.processingExpert:
        return '处理中（专家AI）...';
      case CaptureState.complete:
        return '完成';
      case CaptureState.error:
        return '错误';
    }
  }
}

