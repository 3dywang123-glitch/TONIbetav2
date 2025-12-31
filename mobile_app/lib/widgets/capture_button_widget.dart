import 'package:flutter/material.dart';
import '../models/capture_state.dart';

class CaptureButtonWidget extends StatelessWidget {
  final CaptureState state;
  final VoidCallback? onPressed;

  const CaptureButtonWidget({
    super.key,
    required this.state,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    bool isEnabled = state == CaptureState.idle || state == CaptureState.complete;
    bool isProcessing = state != CaptureState.idle && state != CaptureState.complete && state != CaptureState.error;

    return GestureDetector(
      onTap: isEnabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: isProcessing
              ? Colors.redAccent.withOpacity(0.8)
              : (isEnabled
                    ? Colors.cyanAccent.withOpacity(0.2)
                    : Colors.white10),
          shape: BoxShape.circle,
          border: Border.all(
            color: isEnabled ? Colors.cyanAccent : Colors.white24,
            width: 2,
          ),
          boxShadow: [
            if (isEnabled && !isProcessing)
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.2),
                blurRadius: 20,
              ),
          ],
        ),
        child: isProcessing
            ? const Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              )
            : Icon(
                isProcessing ? Icons.hourglass_top : Icons.camera_alt,
                color: Colors.white,
                size: 28,
              ),
      ),
    );
  }
}

