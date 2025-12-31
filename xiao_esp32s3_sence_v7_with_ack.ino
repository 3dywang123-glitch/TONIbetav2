#include "esp_camera.h"
#include <WiFi.h>
#include <WiFiUdp.h>
#include <Preferences.h>
#include <WebServer.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

// ================= 硬件引脚 =================
#define BTN_FUNC_PIN 1  // D0
#define LED_PIN      2  // D1
#define LASER_PIN    3  // D2
#define BTN_TRIG_PIN 4  // D3

// ================= 蓝牙配网 =================
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define DEVICE_NAME         "TONI_PROV"

// ================= 系统变量 =================
#define UDP_PORT 8888
#define ACK_TIMEOUT 500      // UDP确认超时时间（毫秒）
#define MAX_UDP_RETRIES 3    // UDP事件最大重试次数

Preferences preferences;
WiFiUDP Udp;
WebServer server(80);
char packetBuffer[255];

// 图像缓冲区 (存 PSRAM)
camera_fb_t * fb_vga = NULL;  // 秘书图
camera_fb_t * fb_hd = NULL;   // 专家图

// App IP地址记录（用于UDP事件发送）
IPAddress appIP(0, 0, 0, 0);
uint16_t appPort = 0;

// UDP事件确认状态
bool vgaAckReceived = false;
bool hdAckReceived = false;
unsigned long vgaEventTime = 0;
unsigned long hdEventTime = 0;
int vgaRetryCount = 0;
int hdRetryCount = 0;

// 状态机
enum SystemState { STATE_BOOT, STATE_PROVISION, STATE_CONNECTING, STATE_RUNNING };
SystemState sysState = STATE_BOOT;

enum TacState { IDLE, START, SNAP_VGA, WARMUP, SNAP_HD, DONE };
TacState tacState = IDLE;
unsigned long tacTimer = 0;
bool isArmed = true;
bool funcBtnPressed = false;
unsigned long funcBtnTime = 0;

// 连拍状态
int burstCount = 0;
int burstRemaining = 0;
unsigned long burstTimer = 0;
bool isBursting = false;

// ================= 函数声明 =================
void setupCamera();
void startBleProvisioning();
void handleUdpDiscovery();
void handlePhysicalControls();
void runAutonomousSequence();
void takePictureToBuffer(int slot);
void enterDeepSleep();
void sendVgaEventWithRetry();
void sendHdEventWithRetry();
void checkUdpAckTimeout();
void clearImageCache(int type); // type: 0=VGA, 1=HD, 2=Both

// ================= 蓝牙回调 =================
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String value = pCharacteristic->getValue();
      if (value.length() > 0) {
        Serial.println("📱 BLE: " + value);
        int commaIndex = value.indexOf(',');
        if (commaIndex != -1) {
          String ssid = value.substring(0, commaIndex);
          String pass = value.substring(commaIndex + 1);
          preferences.begin("wifi_config", false);
          preferences.putString("ssid", ssid);
          preferences.putString("pass", pass);
          preferences.end();
          delay(500); ESP.restart();
        }
      }
    }
};

// ================= SETUP =================
void setup() {
  Serial.begin(115200);
  
  pinMode(BTN_FUNC_PIN, INPUT_PULLUP);
  pinMode(BTN_TRIG_PIN, INPUT_PULLUP);
  esp_sleep_enable_ext0_wakeup((gpio_num_t)BTN_FUNC_PIN, 0);

  ledcAttach(LED_PIN, 5000, 8);
  ledcAttach(LASER_PIN, 5000, 8);
  
  // 开机特效
  for(int i=0; i<2; i++) {
    ledcWrite(LED_PIN, 150); delay(100);
    ledcWrite(LED_PIN, 0);   delay(100);
  }
  ledcWrite(LED_PIN, 50);

  setupCamera();

  preferences.begin("wifi_config", true);
  String ssid = preferences.getString("ssid", "");
  String pass = preferences.getString("pass", "");
  preferences.end();

  if (ssid == "") {
    sysState = STATE_PROVISION;
    startBleProvisioning();
  } else {
    WiFi.begin(ssid.c_str(), pass.c_str());
    sysState = STATE_CONNECTING;
  }
}

// ================= LOOP =================
void loop() {
  if (sysState == STATE_PROVISION) {
    static int bri = 0; static int dir = 5;
    bri += dir; if(bri>=255 || bri<=0) dir = -dir;
    ledcWrite(LED_PIN, bri); delay(20);
    return;
  }

  if (sysState == STATE_CONNECTING) {
    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("\n✅ IP: " + WiFi.localIP().toString());
      Udp.begin(UDP_PORT);
      
      // 1. 触发接口 (App 喊这一嗓子就开始干活)
      server.on("/trigger", HTTP_GET, [](){
        WiFiClient client = server.client();
        // 记录App IP地址（用于UDP事件发送）
        appIP = client.remoteIP();
        appPort = client.remotePort();
        Serial.println("📱 App IP: " + appIP.toString() + ":" + String(appPort));
        
        server.send(200, "text/plain", "OK");
        if (tacState == IDLE) {
          tacState = START;
          tacTimer = millis();
          Serial.println("🚀 收到指令，序列启动");
        }
      });

      // 2. 取图接口 - VGA (App 收到 UDP 通知后来取)
      server.on("/latest_vga", HTTP_GET, [](){
        if (fb_vga) {
          server.sendHeader("Content-Type", "image/jpeg");
          WiFiClient client = server.client();
          client.write(fb_vga->buf, fb_vga->len);
          Serial.println("📤 VGA 已发送");
        } else {
          server.send(404, "text/plain", "Not Ready");
        }
      });

      // 3. 取图接口 - HD (App 收到 UDP 通知后来取)
      server.on("/latest_hd", HTTP_GET, [](){
        if (fb_hd) {
          server.sendHeader("Content-Type", "image/jpeg");
          WiFiClient client = server.client();
          client.write(fb_hd->buf, fb_hd->len);
          Serial.println("📤 HD 已发送");
        } else {
          server.send(404, "text/plain", "Not Ready");
        }
      });

      // 4. 图像接收确认接口
      server.on("/ack_image", HTTP_GET, [](){
        String type = server.arg("type");
        Serial.println("✅ 收到图像确认: " + type);
        
        // 收到确认后清除对应缓存，释放PSRAM
        if (type == "VGA") {
          clearImageCache(0); // 清除VGA缓存
        } else if (type == "HD") {
          clearImageCache(1); // 清除HD缓存
        }
        
        server.send(200, "text/plain", "OK");
      });

      // 5. 连拍接口
      server.on("/burst", HTTP_GET, [](){
        String countStr = server.arg("count");
        int count = countStr.toInt();
        
        if (count > 0 && count <= 9) {
          burstCount = count;
          burstRemaining = count;
          isBursting = true;
          burstTimer = millis();
          Serial.println("📸 连拍启动: " + String(count) + " 张");
          server.send(200, "text/plain", "OK");
        } else {
          server.send(400, "text/plain", "Invalid count");
        }
      });

      server.begin();
      sysState = STATE_RUNNING;
    } else {
      if (millis() > 30000) {
        sysState = STATE_PROVISION;
        startBleProvisioning();
      }
      delay(500);
    }
    return;
  }

  if (sysState == STATE_RUNNING) {
    handleUdpDiscovery();
    server.handleClient();
    handlePhysicalControls();
    
    // 检查UDP确认超时并重试
    checkUdpAckTimeout();
    
    // 执行自主序列
    if (tacState != IDLE) {
      runAutonomousSequence();
    }
    
    // 处理连拍序列
    if (isBursting) {
      handleBurstSequence();
    }
  }
}

// ================= V7.0 核心逻辑（带确认和重试） =================

void runAutonomousSequence() {
  unsigned long elapsed = millis() - tacTimer;

  // T+0.1s: 偷拍 VGA (静默)
  if (tacState == START && elapsed >= 100) {
    // 拍之前释放旧缓存
    if (fb_vga) { esp_camera_fb_return(fb_vga); fb_vga = NULL; }
    
    // 拍第一张(废片)
    takePictureToBuffer(0); // 0=VGA slot
    tacState = SNAP_VGA;
  }

  // T+0.6s: 拍 VGA 并通知 App
  else if (tacState == SNAP_VGA && elapsed >= 600) {
    if (fb_vga) { esp_camera_fb_return(fb_vga); fb_vga = NULL; } // 扔掉0.1s那张
    
    takePictureToBuffer(0); // 拍新的 VGA
    Serial.println("📸 VGA Captured");
    
    // 发送UDP事件（带重试机制）
    sendVgaEventWithRetry();
    
    tacState = WARMUP;
  }

  // T+0.6s - T+2.0s: 慢闪
  else if (tacState == WARMUP && elapsed < 2000) {
    int phase = (elapsed / 250) % 2; 
    ledcWrite(LASER_PIN, phase == 0 ? 200 : 0);
    ledcWrite(LED_PIN, phase == 0 ? 255 : 50);
  }

  // T+2.0s: 高清热机
  else if (tacState == WARMUP && elapsed >= 2000) {
    // 切换分辨率拍废片
    if (fb_hd) { esp_camera_fb_return(fb_hd); fb_hd = NULL; }
    takePictureToBuffer(1); // 1=HD slot
    tacState = SNAP_HD;
  }

  // T+2.0s - T+3.0s: 快闪 -> 锁定
  else if (tacState == SNAP_HD && elapsed < 3000) {
    if (elapsed < 2600) {
       int phase = (elapsed / 100) % 2;
       ledcWrite(LASER_PIN, phase == 0 ? 255 : 0);
       ledcWrite(LED_PIN, phase == 0 ? 255 : 20);
    } else {
       ledcWrite(LASER_PIN, 255); // 锁定
       ledcWrite(LED_PIN, 150);
    }
  }

  // T+3.0s: 决战拍大图
  else if (tacState == SNAP_HD && elapsed >= 3000) {
    ledcWrite(LASER_PIN, 0);
    ledcWrite(LED_PIN, 255); // 补光
    delay(50);
    
    if (fb_hd) { esp_camera_fb_return(fb_hd); fb_hd = NULL; }
    takePictureToBuffer(1); // 拍最终 HD
    Serial.println("📸 HD Captured");
    
    // 发送UDP事件（带重试机制）
    sendHdEventWithRetry();
    
    ledcWrite(LED_PIN, 20); // 复位
    tacState = IDLE; // 结束
  }
}

// ================= UDP事件发送（带重试） =================

void sendVgaEventWithRetry() {
  vgaAckReceived = false;
  vgaEventTime = millis();
  vgaRetryCount = 0;
  
  IPAddress targetIP = (appIP[0] != 0) ? appIP : Udp.remoteIP();
  uint16_t targetPort = (appPort != 0) ? appPort : UDP_PORT;
  
  Udp.beginPacket(targetIP, targetPort);
  Udp.print("EVENT:VGA_READY");
  Udp.endPacket();
  Serial.println("📤 发送 VGA_READY 事件 -> " + targetIP.toString());
}

void sendHdEventWithRetry() {
  hdAckReceived = false;
  hdEventTime = millis();
  hdRetryCount = 0;
  
  IPAddress targetIP = (appIP[0] != 0) ? appIP : Udp.remoteIP();
  uint16_t targetPort = (appPort != 0) ? appPort : UDP_PORT;
  
  Udp.beginPacket(targetIP, targetPort);
  Udp.print("EVENT:HD_READY");
  Udp.endPacket();
  Serial.println("📤 发送 HD_READY 事件 -> " + targetIP.toString());
}

// ================= UDP确认超时检查 =================

void checkUdpAckTimeout() {
  unsigned long now = millis();
  
  // 检查VGA确认
  if (!vgaAckReceived && vgaEventTime > 0) {
    if (now - vgaEventTime > ACK_TIMEOUT) {
      if (vgaRetryCount < MAX_UDP_RETRIES) {
        vgaRetryCount++;
        Serial.println("⚠️ VGA确认超时，重试 " + String(vgaRetryCount) + "/" + String(MAX_UDP_RETRIES));
        
        IPAddress targetIP = (appIP[0] != 0) ? appIP : Udp.remoteIP();
        uint16_t targetPort = (appPort != 0) ? appPort : UDP_PORT;
        
        Udp.beginPacket(targetIP, targetPort);
        Udp.print("EVENT:VGA_READY");
        Udp.endPacket();
        vgaEventTime = now; // 重置计时器
      } else {
        Serial.println("❌ VGA确认失败，已达最大重试次数");
        vgaEventTime = 0;
        vgaRetryCount = 0;
      }
    }
  }

  // 检查HD确认
  if (!hdAckReceived && hdEventTime > 0) {
    if (now - hdEventTime > ACK_TIMEOUT) {
      if (hdRetryCount < MAX_UDP_RETRIES) {
        hdRetryCount++;
        Serial.println("⚠️ HD确认超时，重试 " + String(hdRetryCount) + "/" + String(MAX_UDP_RETRIES));
        
        IPAddress targetIP = (appIP[0] != 0) ? appIP : Udp.remoteIP();
        uint16_t targetPort = (appPort != 0) ? appPort : UDP_PORT;
        
        Udp.beginPacket(targetIP, targetPort);
        Udp.print("EVENT:HD_READY");
        Udp.endPacket();
        hdEventTime = now; // 重置计时器
      } else {
        Serial.println("❌ HD确认失败，已达最大重试次数");
        hdEventTime = 0;
        hdRetryCount = 0;
      }
    }
  }
}

// ================= 图像缓存清理 =================

void clearImageCache(int type) {
  // type: 0=VGA, 1=HD, 2=Both
  if (type == 0 || type == 2) {
    if (fb_vga) {
      esp_camera_fb_return(fb_vga);
      fb_vga = NULL;
      Serial.println("🗑️ VGA缓存已清除");
    }
  }
  if (type == 1 || type == 2) {
    if (fb_hd) {
      esp_camera_fb_return(fb_hd);
      fb_hd = NULL;
      Serial.println("🗑️ HD缓存已清除");
    }
  }
}

// ================= 连拍序列处理 =================

void handleBurstSequence() {
  if (burstRemaining <= 0) {
    isBursting = false;
    Serial.println("✅ 连拍完成");
    return;
  }

  unsigned long elapsed = millis() - burstTimer;
  
  // 每500ms拍摄一张
  if (elapsed >= 500) {
    if (fb_hd) { esp_camera_fb_return(fb_hd); fb_hd = NULL; }
    takePictureToBuffer(1); // 拍HD
    Serial.println("📸 连拍 " + String(burstCount - burstRemaining + 1) + "/" + String(burstCount));
    
    // 发送HD_READY事件
    sendHdEventWithRetry();
    
    burstRemaining--;
    burstTimer = millis();
  }
}

// ================= 其他辅助函数 =================

void takePictureToBuffer(int slot) {
  sensor_t * s = esp_camera_sensor_get();
  if (slot == 0) s->set_framesize(s, FRAMESIZE_VGA);
  else s->set_framesize(s, FRAMESIZE_QXGA);
  
  camera_fb_t * new_fb = esp_camera_fb_get();
  
  if (!new_fb) { 
    Serial.println("❌ FB Alloc Fail"); 
    return; 
  }
  
  if (slot == 0) fb_vga = new_fb;
  else fb_hd = new_fb;
}

void handleUdpDiscovery() {
  int packetSize = Udp.parsePacket();
  if (packetSize) {
    int len = Udp.read(packetBuffer, 255);
    if (len > 0) {
      packetBuffer[len] = 0;
      String message = String(packetBuffer);
      
      // 处理设备发现
      if (message.indexOf("WHO_IS_TONI") != -1) {
        String reply = "I_AM_TONI,SSID=" + WiFi.SSID() + ",IP=" + WiFi.localIP().toString();
        Udp.beginPacket(Udp.remoteIP(), Udp.remotePort());
        Udp.print(reply);
        Udp.endPacket();
      }
      
      // 处理确认消息
      if (message.startsWith("ACK:")) {
        String eventType = message.substring(4);
        if (eventType == "VGA_READY") {
          vgaAckReceived = true;
          vgaEventTime = 0; // 停止重试
          Serial.println("✅ 收到VGA确认");
        } else if (eventType == "HD_READY") {
          hdAckReceived = true;
          hdEventTime = 0; // 停止重试
          Serial.println("✅ 收到HD确认");
        }
      }
    }
  }
}

void handlePhysicalControls() {
  int btnState = digitalRead(BTN_FUNC_PIN);
  if (btnState == LOW) { 
    if (!funcBtnPressed) { funcBtnPressed = true; funcBtnTime = millis(); }
    if (millis() - funcBtnTime > 2000) enterDeepSleep(); 
  } else {
    if (funcBtnPressed && millis() - funcBtnTime < 2000) {
      isArmed = !isArmed;
      ledcWrite(LED_PIN, isArmed ? 255 : 0); delay(100); 
      ledcWrite(LED_PIN, 0); delay(100);
    }
    funcBtnPressed = false;
  }

  if (isArmed && tacState == IDLE) {
    static int lastTrig = HIGH;
    int trig = digitalRead(BTN_TRIG_PIN);
    if (lastTrig == HIGH && trig == LOW) {
      delay(20);
      if (digitalRead(BTN_TRIG_PIN) == LOW) {
        Serial.println("🔘 Trigger!");
        tacState = START;
        tacTimer = millis();
      }
    }
    lastTrig = trig;
  }
}

void enterDeepSleep() {
  ledcWrite(LED_PIN, 0); ledcWrite(LASER_PIN, 0);
  esp_deep_sleep_start();
}

void startBleProvisioning() {
  BLEDevice::init(DEVICE_NAME);
  BLEServer *pServer = BLEDevice::createServer();
  BLEService *pService = pServer->createService(SERVICE_UUID);
  BLECharacteristic *pCharacteristic = pService->createCharacteristic(
                                         CHARACTERISTIC_UUID,
                                         BLECharacteristic::PROPERTY_WRITE
                                       );
  pCharacteristic->setCallbacks(new MyCallbacks());
  pService->start();
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06); 
  BLEDevice::startAdvertising();
}

void setupCamera() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = 8; config.pin_d1 = 9; config.pin_d2 = 40; config.pin_d3 = 39;
  config.pin_d4 = 41; config.pin_d5 = 42; config.pin_d6 = 12; config.pin_d7 = 11;
  config.pin_xclk = 10; config.pin_pclk = 13; config.pin_vsync = 38; config.pin_href = 47;
  config.pin_sscb_sda = 4; config.pin_sscb_scl = 5; config.pin_pwdn = -1; config.pin_reset = -1;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size = FRAMESIZE_SVGA; 
  config.jpeg_quality = 12;
  config.fb_count = 2;
  config.fb_location = CAMERA_FB_IN_PSRAM;
  
  if (esp_camera_init(&config) != ESP_OK) Serial.println("❌ Cam Init Fail");
  else Serial.println("✅ Cam Ready");
}

