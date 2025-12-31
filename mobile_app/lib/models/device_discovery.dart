class DiscoveredDevice {
  final String ip;
  final String ssid;
  final DateTime discoveredAt;

  DiscoveredDevice({
    required this.ip,
    required this.ssid,
    required this.discoveredAt,
  });

  @override
  String toString() => 'DiscoveredDevice(ip: $ip, ssid: $ssid)';
}

enum DeviceConnectionState {
  disconnected,
  discovering,
  connected,
  provisioning,
}

