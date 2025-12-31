enum CaptureState {
  idle,
  triggered,
  waitingVga,
  vgaReady,
  waitingHd,
  hdReady,
  processingSecretary,
  bursting, // 连拍中
  processingExpert,
  complete,
  error,
}

class CaptureSession {
  final String sessionId;
  final DateTime startTime;
  CaptureState state;
  String? firstCommand;
  String? fullContext;
  String? secretaryReply;
  String? expertType;
  String? cameraAction;
  String? expertReply;
  int? burstCount; // 需要连拍的数量
  int currentBurstIndex = 0; // 当前连拍索引

  CaptureSession({
    required this.sessionId,
    required this.startTime,
    this.state = CaptureState.idle,
    this.firstCommand,
    this.fullContext,
    this.secretaryReply,
    this.expertType,
    this.cameraAction,
    this.expertReply,
    this.burstCount,
    this.currentBurstIndex = 0,
  });
}

