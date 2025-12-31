# Toni Smart Camera System

Complete implementation of Toni smart camera system with Flutter mobile app and Node.js backend.

## Project Structure

```
Toniappbetav2/
├── mobile_app/          # Flutter mobile application
├── backend/             # Node.js backend service
└── README.md           # This file
```

## Components

### Mobile App (Flutter)
- Automatic device discovery via UDP broadcast
- BLE provisioning for WiFi setup
- Real-time image capture with event-driven notifications
- Voice activity detection and speech recognition
- Dual AI processing integration
- Image caching and processing

### Backend (Node.js)
- Secretary AI endpoint for initial analysis
- Expert AI endpoint for detailed analysis
- Configurable AI service integration
- Image processing support

## Quick Start

### Mobile App

1. Navigate to `mobile_app/`:
```bash
cd mobile_app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Backend

1. Navigate to `backend/`:
```bash
cd backend
```

2. Install dependencies:
```bash
npm install
```

3. Create `.env` file (copy from `.env.example`):
```bash
cp .env.example .env
```

4. Configure your AI endpoint in `.env`:
```
BACKEND_AI_ENDPOINT=https://api.openai.com/v1/chat/completions
OPENAI_API_KEY=your_api_key_here
PORT=3000
```

5. Start the server:
```bash
npm start
```

## Firmware Integration

The system works with existing ESP32 firmware that provides:
- UDP discovery on port 8888
- HTTP endpoints: `/trigger`, `/latest_vga`, `/latest_hd`
- UDP event notifications: `EVENT:VGA_READY`, `EVENT:HD_READY`
- BLE provisioning as `TONI_PROV`

## Workflow

1. **Device Discovery**: App broadcasts `WHO_IS_TONI?` and receives device IP
2. **Capture Trigger**: User triggers capture → App calls `GET /trigger`
3. **Image Capture**: Device sends UDP events → App fetches images
4. **Audio Processing**: VAD detects speech → Speech recognition extracts text
5. **Secretary AI**: VGA image + first command → Initial analysis
6. **Expert AI**: HD image + full context → Detailed analysis

## Configuration

### Mobile App
- UDP Discovery Port: 8888
- HTTP Server Port: 80
- BLE Service UUID: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- BLE Characteristic UUID: `beb5483e-36e1-4688-b7f5-ea07361b26a8`

### Backend
- Default Port: 3000
- AI Endpoint: Configurable via environment variable
- Image formats: VGA (640x480), QXGA (2048x1536), Crop (540x720)

## License

ISC

