import 'package:flutter/material.dart';
import '../models/device_discovery.dart';
import '../services/network/device_discovery_service.dart';

class DeviceStatusWidget extends StatelessWidget {
  final DeviceDiscoveryService discoveryService;

  const DeviceStatusWidget({
    super.key,
    required this.discoveryService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: discoveryService,
      builder: (context, child) {
        final device = discoveryService.currentDevice;
        final state = discoveryService.state;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: state == DeviceConnectionState.connected 
                  ? Colors.cyanAccent 
                  : Colors.grey,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: state == DeviceConnectionState.connected 
                      ? Colors.cyanAccent 
                      : Colors.grey,
                  shape: BoxShape.circle,
                  boxShadow: state == DeviceConnectionState.connected
                      ? [const BoxShadow(color: Colors.cyanAccent, blurRadius: 6)]
                      : [],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                state == DeviceConnectionState.connected 
                    ? 'ARMED' 
                    : (state == DeviceConnectionState.discovering 
                        ? 'SCANNING' 
                        : 'REST'),
                style: TextStyle(
                  color: state == DeviceConnectionState.connected 
                      ? Colors.cyanAccent 
                      : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              if (device != null) ...[
                const SizedBox(width: 8),
                Text(
                  device.ip,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

