import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

class YoloScreen extends StatefulWidget {
  const YoloScreen({super.key});

  @override
  State<YoloScreen> createState() => _YoloScreenState();
}

class _YoloScreenState extends State<YoloScreen> {
  List<Map<String, dynamic>> _detections = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Face Detection (${_detections.length})'),
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          YOLOView(
            modelPath: 'model_face.tflite',
            task: YOLOTask.detect,
            confidenceThreshold: 0.5,
            iouThreshold: 0.7,  // ← Tăng để giảm boxes trùng nhau
            useGpu: true,
            // ❌ XÓA dòng boxColor - không tồn tại!
            onResult: (results) {
              print('🔍 Detection results: $results');
              if (results != null && results.isNotEmpty) {
                print('📊 Found ${results.length} objects');
                for (var r in results) {
                  print('   - ${r.className}: ${r.confidence}');
                }
              }
              final mapped = _mapResults(results);
              setState(() => _detections = mapped);
            },
          ),

          // Overlay hiển thị thông tin
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
                    'Detections: ${_detections.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_detections.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _detections
                          .map((d) =>
                      '${d['label']}: ${(d['confidence'] * 100).toStringAsFixed(1)}%')
                          .join('\n'),
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

  List<Map<String, dynamic>> _mapResults(dynamic results) {
    final out = <Map<String, dynamic>>[];
    if (results == null) return out;

    for (final r in results) {
      try {
        out.add({
          'x': (r.rect?.left ?? 0).toDouble(),
          'y': (r.rect?.top ?? 0).toDouble(),
          'w': (r.rect?.width ?? 0).toDouble(),
          'h': (r.rect?.height ?? 0).toDouble(),
          'confidence': (r.confidence as num?)?.toDouble() ?? 0.0,
          'label': r.className ?? 'face',
        });
      } catch (e) {
        print('⚠️ Mapping error: $e');
      }
    }
    return out;
  }
}