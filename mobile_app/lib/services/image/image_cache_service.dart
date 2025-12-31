import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ImageCacheService extends ChangeNotifier {
  Uint8List? _cacheA; // VGA secretary image
  Uint8List? _cacheB; // QXGA expert image (first HD image)
  Uint8List? _cacheC; // Cropped 540x720 image
  List<Uint8List> _burstImages = []; // Burst images (including first HD as index 0)

  Uint8List? get cacheA => _cacheA;
  Uint8List? get cacheB => _cacheB;
  Uint8List? get cacheC => _cacheC;
  List<Uint8List> get burstImages => List.unmodifiable(_burstImages);
  int get burstCount => _burstImages.length;

  Future<void> setCacheA(Uint8List imageData) async {
    _cacheA = imageData;
    notifyListeners();
    debugPrint('Cache A (VGA) set: ${imageData.length} bytes');
  }

  Future<void> setCacheB(Uint8List imageData) async {
    _cacheB = imageData;
    
    // If this is the first HD image, add it to burst images as index 0
    if (_burstImages.isEmpty) {
      _burstImages.add(imageData);
      debugPrint('Burst image 0 (first HD) added');
    }
    
    notifyListeners();
    debugPrint('Cache B (HD) set: ${imageData.length} bytes');

    // Auto-crop to 540x720
    await _cropToCacheC();
  }

  /// Add a burst image (after the first HD image)
  Future<void> addBurstImage(Uint8List imageData) async {
    _burstImages.add(imageData);
    notifyListeners();
    debugPrint('Burst image ${_burstImages.length - 1} added: ${imageData.length} bytes');
  }

  /// Get all images for expert AI (first HD + burst images)
  List<Uint8List> getAllExpertImages() {
    return List.unmodifiable(_burstImages);
  }

  Future<void> _cropToCacheC() async {
    if (_cacheB == null) return;

    try {
      // Decode JPEG
      final image = img.decodeImage(_cacheB!);
      if (image == null) {
        debugPrint('Failed to decode image for cropping');
        return;
      }

      final width = image.width;
      final height = image.height;
      final targetWidth = 540;
      final targetHeight = 720;

      // Calculate center crop
      final cropX = (width - targetWidth) ~/ 2;
      final cropY = (height - targetHeight) ~/ 2;

      // Ensure crop coordinates are valid
      final actualCropX = cropX.clamp(0, width - targetWidth);
      final actualCropY = cropY.clamp(0, height - targetHeight);
      final actualCropWidth = targetWidth.clamp(1, width - actualCropX);
      final actualCropHeight = targetHeight.clamp(1, height - actualCropY);

      // Crop image
      final cropped = img.copyCrop(
        image,
        x: actualCropX,
        y: actualCropY,
        width: actualCropWidth,
        height: actualCropHeight,
      );

      // Encode back to JPEG
      _cacheC = Uint8List.fromList(img.encodeJpg(cropped, quality: 85));
      notifyListeners();
      debugPrint('Cache C (cropped) set: ${_cacheC!.length} bytes (${actualCropWidth}x${actualCropHeight})');
    } catch (e) {
      debugPrint('Crop error: $e');
    }
  }

  void clearCache() {
    _cacheA = null;
    _cacheB = null;
    _cacheC = null;
    _burstImages.clear();
    notifyListeners();
    debugPrint('Image cache cleared');
  }

  Future<String?> saveImageToFile(Uint8List imageData, String filename) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(imageData);
      debugPrint('Image saved: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('Save image error: $e');
      return null;
    }
  }
}

