import 'dart:io';
import 'package:app_mobile/screen/emotion_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:image/image.dart' as img;

class YoloScreen extends StatefulWidget {
  const YoloScreen({super.key});

  @override
  State<YoloScreen> createState() => _YoloScreenState();
}

class _YoloScreenState extends State<YoloScreen> {
  int _count = 0;
  String _info = '';
  CameraController? _cameraController;
  List<YOLOResult>? _lastResults;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  /// Chụp ảnh và crop khuôn mặt với scale đúng
  Future<void> _captureAndAnalyzeFace() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _lastResults == null ||
        _lastResults!.isEmpty ||
        _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      // 1. Chụp ảnh
      final image = await _cameraController!.takePicture();

      // 2. Load ảnh để crop
      final bytes = await File(image.path).readAsBytes();
      final originalImage = img.decodeImage(bytes);

      if (originalImage == null) {
        throw Exception('Không thể decode ảnh');
      }

      print('📸 Original image size: ${originalImage.width}x${originalImage.height}');

      // 3. Lấy bounding box của face đầu tiên
      final firstFace = _lastResults!.first;
      final box = firstFace.boundingBox;

      print('📦 Box from YOLO (preview coords): ${box.left}, ${box.top}, ${box.width}, ${box.height}');

      // 4. ✅ QUAN TRỌNG: Tính tỷ lệ scale giữa ảnh chụp và preview
      // Preview size từ YOLOView (thường là 480x640 hoặc tùy device)
      // Bạn cần lấy preview size thực tế, tạm thời dùng giá trị ước lượng
      final previewWidth = 640.0;
      final previewHeight = 480.0;

      final scaleX = originalImage.width / previewHeight; // Scale X của ảnh (720) với Y của stream (480)
      final scaleY = originalImage.height / previewWidth; // Scale Y của ảnh (1280) với X của stream (640)

      print('📐 Scale factors: scaleX=$scaleX, scaleY=$scaleY');

      // 5. Scale bounding box lên kích thước ảnh thực
      final padding = -30.0;

      final scaledLeft = (box.left * scaleX - padding).clamp(0.0, originalImage.width.toDouble());
      final scaledTop = (box.top * scaleY - padding).clamp(0.0, originalImage.height.toDouble());
      final scaledWidth = (box.width * scaleX + padding * 2).clamp(0.0, originalImage.width - scaledLeft);
      final scaledHeight = (box.height * scaleY + padding * 2).clamp(0.0, originalImage.height - scaledTop);

      final x = scaledLeft.toInt();
      final y = scaledTop.toInt();
      final w = scaledWidth.toInt();
      final h = scaledHeight.toInt();

      print('✂️ Crop coords: x=$x, y=$y, w=$w, h=$h');

      // 6. Crop khuôn mặt
      final croppedFace = img.copyCrop(
        originalImage,
        x: x,
        y: y,
        width: w,
        height: h,
      );

      print('✅ Cropped face size: ${croppedFace.width}x${croppedFace.height}');

      // 7. Lưu ảnh đã crop
      final tempDir = await getTemporaryDirectory();
      final facePath = '${tempDir.path}/face_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(facePath).writeAsBytes(img.encodeJpg(croppedFace));

      print('💾 Saved cropped face to: $facePath');

      // 8. Chuyển sang màn hình phân tích cảm xúc
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmotionResultScreen(
              faceImagePath: facePath,
            ),
          ),
        );
      }

    } catch (e) {
      print('❌ Error capturing face: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Face Detection ($_count)'),
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          /// Camera + YOLO Detection
          YOLOView(
            modelPath: 'model_face.tflite',
            task: YOLOTask.detect,
            confidenceThreshold: 0.5,
            iouThreshold: 0.7,
            useGpu: true,
            onResult: (results) {
              if (results == null || results.isEmpty) {
                setState(() {
                  _count = 0;
                  _info = '';
                  _lastResults = null;
                });
                return;
              }

              print('🔍 Detection results: $results');
              print('📊 Found ${results.length} faces');

              setState(() {
                _count = results.length;
                _lastResults = results;
                _info = results
                    .map((r) =>
                '${r.className ?? 'face'}: ${(r.confidence * 100).toStringAsFixed(1)}%')
                    .join('\n');
              });
            },
          ),

          /// Info Overlay
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueAccent, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Phát hiện: $_count khuôn mặt',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_info.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _info,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),

          /// Capture Button
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton.extended(
                onPressed: _count > 0 && !_isCapturing ? _captureAndAnalyzeFace : null,
                backgroundColor: _count > 0 ? Colors.blue : Colors.grey,
                icon: _isCapturing
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.camera_alt),
                label: Text(_isCapturing ? 'Đang xử lý...' : 'Phân tích cảm xúc'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}