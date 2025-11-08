// import 'dart:math' as math;
// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
// import 'package:image/image.dart' as img;
//
// class EmptyScreen extends StatefulWidget {
//   final List<CameraDescription> cameras;
//   const EmptyScreen({super.key, required this.cameras});
//
//   @override
//   State<EmptyScreen> createState() => _EmptyScreenState();
// }
//
// class _EmptyScreenState extends State<EmptyScreen> {
//   CameraController? _controller;
//   bool _isDetecting = false;
//   bool _isModelReady = false;
//   List<Map<String, dynamic>> _detections = [];
//   late tfl.Interpreter _interpreter;
//
//   static const int _inputWidth = 640;
//   static const int _inputHeight = 640;
//   static const double _confidenceThreshold = 0.4; // Tăng lên để loại rác
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeEverything();
//   }
//
//   Future<void> _initializeEverything() async {
//     await _loadModel();
//     await _initCamera();
//   }
//
//   Future<void> _loadModel() async {
//     try {
//       _interpreter = await tfl.Interpreter.fromAsset('assets/model_face.tflite');
//       _isModelReady = true;
//       print("YOLOv11 TFLite model loaded successfully");
//     } catch (e) {
//       print("Error loading model: $e");
//     }
//   }
//
//   Future<void> _initCamera() async {
//     if (widget.cameras.isEmpty) {
//       print("No cameras found");
//       return;
//     }
//
//     final frontCamera = widget.cameras.firstWhere(
//           (c) => c.lensDirection == CameraLensDirection.front,
//       orElse: () => widget.cameras.first,
//     );
//
//     _controller = CameraController(
//       frontCamera,
//       ResolutionPreset.medium,
//       enableAudio: false,
//       imageFormatGroup: ImageFormatGroup.nv21,
//     );
//
//     await _controller!.initialize();
//     if (!mounted) return;
//     setState(() {});
//     print("Camera initialized (front)");
//     _startDetection();
//   }
//
//   void _startDetection() {
//     if (!_isModelReady) return;
//
//     _controller!.startImageStream((image) async {
//       if (_isDetecting || !_isModelReady) return;
//       _isDetecting = true;
//
//       try {
//         final detections = await _processCameraImage(image);
//         if (mounted) {
//           setState(() => _detections = detections);
//         }
//       } catch (e) {
//         print("Detection error: $e");
//       } finally {
//         _isDetecting = false;
//       }
//     });
//   }
//
//   // LETTERBOX RESIZE + PAD 114
//   img.Image _letterbox(img.Image src, int w, int h) {
//     final scale = math.min(w / src.width, h / src.height);
//     final newW = (src.width * scale).round();
//     final newH = (src.height * scale).round();
//     final resized = img.copyResize(src, width: newW, height: newH);
//
//     final padded = img.Image(width: w, height: h);
//     img.fill(padded, color: img.ColorRgb8(114, 114, 114)); // pad xám đúng cách
//
//     final dx = (w - newW) ~/ 2;
//     final dy = (h - newH) ~/ 2;
//     img.compositeImage(padded, resized, dstX: dx, dstY: dy);
//     return padded;
//   }
//
//   Future<List<Map<String, dynamic>>> _processCameraImage(CameraImage image) async {
//     try {
//       // 1. YUV → RGB
//       final img.Image cameraImg = _convertYUV420ToImage(image);
//
//       // 2. Letterbox resize
//       final img.Image resized = _letterbox(cameraImg, _inputWidth, _inputHeight);
//
//       // 3. Input [1,640,640,3]
//       var input = List.filled(1, List.filled(640, List.filled(640, List.filled(3, 0.0))));
//
//       for (int y = 0; y < 640; y++) {
//         for (int x = 0; x < 640; x++) {
//           final px = resized.getPixel(x, y);
//           input[0][y][x] = [px.r / 255.0, px.g / 255.0, px.b / 255.0];
//         }
//       }
//
//       // 4. Output [1,5,8400] – ĐÃ SỬA
//       var output = List.filled(1, List.filled(5, List.filled(8400, 0.0)));
//       _interpreter.run(input, output);
//
//       final out = output[0]; // [5,8400] – BÂY GIỜ ỔN
//
//       final List<Map<String, dynamic>> detections = [];
//       double maxConf = 0.0;
//
//       for (int i = 0; i < 8400; i++) {
//         final cx = out[0][i];
//         final cy = out[1][i];
//         final w = out[2][i];
//         final h = out[3][i];
//         final conf = out[4][i];
//
//         if (conf < _confidenceThreshold) continue;
//         maxConf = math.max(maxConf, conf);
//
//         final x = (cx - w / 2).clamp(0.0, 1.0);
//         final y = (cy - h / 2).clamp(0.0, 1.0);
//         final ww = w.clamp(0.0, 1.0);
//         final hh = h.clamp(0.0, 1.0);
//
//         detections.add({
//           'x': x, 'y': y, 'w': ww, 'h': hh,
//           'confidence': conf,
//           'label': 'face',
//         });
//       }
//
//       print("Max conf: ${maxConf.toStringAsFixed(3)} | Raw: ${detections.length}");
//       final nmsed = _nonMaxSuppression(detections, iouThreshold: 0.4);
//       return nmsed.take(20).toList();
//     } catch (e) {
//       print("Error in _processCameraImage: $e");
//
//       return [];
//     }
//   }
//
//
//
//   List<Map<String, dynamic>> _nonMaxSuppression(
//       List<Map<String, dynamic>> boxes, {double iouThreshold = 0.4}) {
//     if (boxes.isEmpty) return [];
//     boxes.sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));
//
//     final keep = <Map<String, dynamic>>[];
//     for (final box in boxes) {
//       bool suppress = false;
//       final x1 = box['x'], y1 = box['y'], x2 = x1 + box['w'], y2 = y1 + box['h'];
//
//       for (final k in keep) {
//         final kx1 = k['x'], ky1 = k['y'], kx2 = kx1 + k['w'], ky2 = ky1 + k['h'];
//         final interX1 = math.max(x1, kx1), interY1 = math.max(y1, ky1);
//         final interX2 = math.min(x2, kx2), interY2 = math.min(y2, ky2);
//         final interW = math.max(0.0, interX2 - interX1);
//         final interH = math.max(0.0, interY2 - interY1);
//         final interArea = interW * interH;
//         final area1 = (x2 - x1) * (y2 - y1);
//         final area2 = (kx2 - kx1) * (ky2 - ky1);
//         final iou = interArea / (area1 + area2 - interArea);
//         if (iou > iouThreshold) {
//           suppress = true;
//           break;
//         }
//       }
//       if (!suppress) keep.add(box);
//       if (keep.length >= 20) break;
//     }
//     return keep;
//
//   }
//
//   img.Image _convertYUV420ToImage(CameraImage image) {
//     final width = image.width;
//     final height = image.height;
//     final rgb = img.Image(width: width, height: height);
//
//     final uvRowStride = image.planes[1].bytesPerRow;
//     final uvPixelStride = image.planes[1].bytesPerPixel!;
//
//     for (int y = 0; y < height; y++) {
//       for (int x = 0; x < width; x++) {
//         final uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
//         final yp = image.planes[0].bytes[y * width + x];
//         final up = image.planes[1].bytes[uvIndex];
//         final vp = image.planes[2].bytes[uvIndex];
//
//         int r = (yp + 1.402 * (vp - 128)).round().clamp(0, 255);
//         int g = (yp - 0.34414 * (up - 128) - 0.71414 * (vp - 128)).round().clamp(0, 255);
//         int b = (yp + 1.772 * (up - 128)).round().clamp(0, 255);
//
//         rgb.setPixel(x, y, img.ColorRgb8(r, g, b));
//       }
//     }
//     return rgb;
//   }
//
//
//
//   @override
//   void dispose() {
//     _controller?.dispose();
//     _interpreter.close();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_controller == null || !_controller!.value.isInitialized) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("YOLOv11 Face Detection (${_detections.length})"),
//         backgroundColor: Colors.black,
//       ),
//       body: Stack(
//         fit: StackFit.expand,
//         children: [
//           Transform(
//             alignment: Alignment.center,
//             transform: Matrix4.rotationY(math.pi),
//             child: CameraPreview(_controller!),
//           ),
//           CustomPaint(painter: BoxPainter(_detections)),
//           Positioned(
//             bottom: 20,
//             left: 20,
//             child: Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: Colors.black54,
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Text(
//                 'Detections: ${_detections.length}\nThreshold: ${(_confidenceThreshold * 100).toInt()}%',
//                 style: const TextStyle(color: Colors.white, fontSize: 14),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class BoxPainter extends CustomPainter {
//   final List<Map<String, dynamic>> detections;
//   BoxPainter(this.detections);
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = Colors.greenAccent
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 3;
//
//     final textPainter = TextPainter(textDirection: TextDirection.ltr);
//
//     for (final d in detections) {
//       final x = d['x'] * size.width;
//       final y = d['y'] * size.height;
//       final w = d['w'] * size.width;
//       final h = d['h'] * size.height;
//       final conf = d['confidence'] as double;
//
//       canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
//
//       final text = 'face ${(conf * 100).toStringAsFixed(1)}%';
//       textPainter.text = TextSpan(
//         text: text,
//         style: const TextStyle(
//           color: Colors.greenAccent,
//           fontSize: 14,
//           backgroundColor: Colors.black54,
//           fontWeight: FontWeight.bold,
//         ),
//       );
//       textPainter.layout();
//       textPainter.paint(canvas, Offset(x, y - 22));
//     }
//   }
//
//   @override
//   bool shouldRepaint(covariant CustomPainter old) => true;
// }