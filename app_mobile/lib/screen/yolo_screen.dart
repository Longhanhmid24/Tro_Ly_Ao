import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

class YoloScreen extends StatefulWidget {
  const YoloScreen({super.key});

  @override
  State<YoloScreen> createState() => _YoloScreenState();
}

class _YoloScreenState extends State<YoloScreen> {
  int _count = 0; // Số lượng phát hiện
  String _info = ''; // Thông tin hiển thị (nhãn + confidence)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Face Detection ($_count)'),
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          /// Camera + mô hình YOLO
          YOLOView(
            modelPath: 'model_face.tflite',
            task: YOLOTask.detect,
            confidenceThreshold: 0.5,
            iouThreshold: 0.7,
            useGpu: true,

            /// Callback khi có kết quả nhận dạng
            onResult: (results) {
              if (results == null || results.isEmpty) {
                setState(() {
                  _count = 0;
                  _info = '';
                });
                return;
              }

              // In log để kiểm tra
              print('🔍 Detection results: $results');
              print('📊 Found ${results.length} objects');

              // Cập nhật hiển thị text
              setState(() {
                _count = results.length;
                _info = results
                    .map((r) =>
                '${r.className ?? 'face'}: ${(r.confidence * 100).toStringAsFixed(1)}%')
                    .join('\n');
              });
            },
          ),

          // Overlay hiển thị thông tin kết quả
          Positioned(
            bottom: 20,
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
                    'Detections: $_count',
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
        ],
      ),
    );
  }
}
