import 'dart:io';
import 'package:app_mobile/screen/emotion_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:image/image.dart' as img;
import '../global.dart';

final apiUrl = "http://$globalIP:8000/generate";

class YoloScreen extends StatefulWidget {
  const YoloScreen({super.key});

  @override
  State<YoloScreen> createState() => _YoloScreenState();
}

class _YoloScreenState extends State<YoloScreen> {
  int _count = 0;
  String _info = '';
  // Không khởi tạo controller ngay lập tức để tránh xung đột
  CameraController? _cameraController; 
  List<YOLOResult>? _lastResults;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    // ⚠️ QUAN TRỌNG: Đã xóa _initCamera() ở đây.
    // Để YOLOView tự quyền kiểm soát camera lúc đầu.
  }

  /// Quy trình: Tắt YOLO -> Đợi camera nghỉ -> Bật Controller -> Chụp -> Tắt Controller
  Future<void> _captureAndAnalyzeFace() async {
    // Điều kiện an toàn
    if (_lastResults == null || _lastResults!.isEmpty || _isCapturing) {
      return;
    }

    // 1. Chuyển trạng thái để ẨN YOLOView trên UI (Giải phóng phần cứng camera)
    setState(() => _isCapturing = true);

    try {
      // 2. Đợi 200ms để camera kịp đóng hoàn toàn
      await Future.delayed(const Duration(milliseconds: 200));

      // 3. Bây giờ mới khởi tạo CameraController
      final cameras = await availableCameras();
      
      CameraDescription? frontCamera;
      try {
        frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
        );
      } catch (e) {
        frontCamera = cameras.first;
      }

      _cameraController = CameraController(
        frontCamera!,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      // 4. Chụp ảnh
      final image = await _cameraController!.takePicture();

      // 5. Tắt CameraController ngay lập tức để giải phóng RAM
      await _cameraController!.dispose();
      _cameraController = null;

      // --- BẮT ĐẦU XỬ LÝ ẢNH (Logic Scale & Crop của bạn giữ nguyên) ---
      final bytes = await File(image.path).readAsBytes();
      final originalImage = img.decodeImage(bytes);

      if (originalImage == null) throw Exception('Không thể decode ảnh');

      print('📸 Original image size: ${originalImage.width}x${originalImage.height}');

      final firstFace = _lastResults!.first;
      final box = firstFace.boundingBox;

      // Scale Factors
      final previewWidth = 640.0;
      final previewHeight = 480.0;
      final scaleX = originalImage.width / previewHeight; 
      final scaleY = originalImage.height / previewWidth; 

      // Coordinates Calculation
      final padding = 25.0;
      final scaledLeft = (box.left * scaleX - padding).clamp(0.0, originalImage.width.toDouble());
      final scaledTop = (box.top * scaleY - padding).clamp(0.0, originalImage.height.toDouble());
      final scaledWidth = (box.width * scaleX + padding * 2).clamp(0.0, originalImage.width - scaledLeft);
      final scaledHeight = (box.height * scaleY + padding * 2).clamp(0.0, originalImage.height - scaledTop);

      final croppedFace = img.copyCrop(
        originalImage,
        x: scaledLeft.toInt(),
        y: scaledTop.toInt(),
        width: scaledWidth.toInt(),
        height: scaledHeight.toInt(),
      );

      // Lưu file
      final tempDir = await getTemporaryDirectory();
      final facePath = '${tempDir.path}/face_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(facePath).writeAsBytes(img.encodeJpg(croppedFace));

      // 6. Chuyển màn hình kết quả
      if (mounted) {
        // Reset trạng thái trước khi đi (để khi back lại thì YOLO hiện lại)
        setState(() => _isCapturing = false);

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
        // Nếu lỗi thì bật lại YOLO để người dùng thử lại
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
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
          /// LOGIC QUAN TRỌNG NHẤT:
          /// Nếu KHÔNG chụp -> Hiện YOLO (Soi gương)
          /// Nếu ĐANG chụp -> Ẩn YOLO (Để nhả camera cho Controller chụp)
          if (!_isCapturing)
            YOLOView(
              lensFacing: LensFacing.front, 
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
                setState(() {
                  _count = results.length;
                  _lastResults = results;
                  _info = results
                      .map((r) => '${r.className ?? 'face'}: ${(r.confidence * 100).toStringAsFixed(1)}%')
                      .join('\n');
                });
              },
            )
          else
            // Màn hình chờ màu đen khi đang xử lý chụp
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.blue),
                    SizedBox(height: 20),
                    Text("Đang xử lý ảnh...", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),

          /// Info Overlay (Chỉ hiện khi đang soi)
          if (!_isCapturing)
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
                // ĐIỀU KIỆN CHUẨN CỦA BẠN: CHỈ KHI COUNT == 1
                onPressed: (_count == 1 && !_isCapturing) 
                    ? _captureAndAnalyzeFace 
                    : null,
                
                backgroundColor: _count == 1 ? Colors.blue : Colors.grey,
                
                icon: _isCapturing
                    ? const SizedBox(width: 0, height: 0) // Ẩn icon khi đang load
                    : const Icon(Icons.camera_alt),
                
                label: Text(
                  _isCapturing 
                      ? 'Vui lòng giữ nguyên...' 
                      : _count == 0 
                          ? 'Chưa thấy mặt' 
                          : _count > 1 
                              ? 'Chỉ chọn 1 người!'
                              : 'Phân tích cảm xúc'
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}