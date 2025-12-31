# Toni Mobile App

Flutter mobile application for Toni smart camera device.

## Features

- Automatic device discovery via UDP broadcast
- BLE provisioning for WiFi setup
- Real-time image capture with event-driven notifications
- Voice activity detection and speech recognition
- Dual AI processing (Secretary → Expert)
- Image caching and processing

## Setup

1. Install Flutter dependencies:
```bash
flutter pub get
```

2. Run the app:
```bash
flutter run
```

## Configuration

- UDP Discovery Port: 8888
- HTTP Server Port: 80 (ESP32 default)
- BLE Service UUID: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- BLE Characteristic UUID: `beb5483e-36e1-4688-b7f5-ea07361b26a8`

