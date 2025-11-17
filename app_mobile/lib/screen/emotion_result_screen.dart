// emotion_result_screen.dart (PHIÊN BẢN SỬA LỖI SHAPE)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class EmotionResultScreen extends StatefulWidget {
  final String faceImagePath;

  const EmotionResultScreen({
    super.key,
    required this.faceImagePath,
  });

  @override
  State<EmotionResultScreen> createState() => _EmotionResultScreenState();
}

class _EmotionResultScreenState extends State<EmotionResultScreen> {
  String _emotion = '';
  double _confidence = 0.0;
  bool _isAnalyzing = true;

  Interpreter? _interpreter;

  // Model của bạn có 8 class cảm xúc
  final List<String> _labels = [
    'Anger',
    'Contempt',
    'Disgust',
    'Fear',
    'Happy',
    'Neutral',
    'Sad',
    'Surprise',
  ];

  final Map<String, List<dynamic>> _emotions = {
    'Anger': ['Tức giận', Colors.red],
    'Contempt': ['Khinh thường', Colors.purple],
    'Disgust': ['Ghê tởm', Colors.green],
    'Fear': ['Sợ hãi', Colors.orange],
    'Happy': ['Vui vẻ', Colors.yellow],
    'Neutral': ['Bình thường', Colors.blueGrey],
    'Sad': ['Buồn bã', Colors.blue],
    'Surprise': ['Ngạc nhiên', Colors.pink],
  };

  String _getEmotionName(String key) => _emotions[key]?[0] ?? 'Không xác định';
  Color _getEmotionColor(String key) => _emotions[key]?[1] ?? Colors.grey;

  @override
  void initState() {
    super.initState();
    _loadModelAndAnalyze();
  }

  Future<void> _loadModelAndAnalyze() async {
    setState(() => _isAnalyzing = true);

    try {
      print('📦 Loading emotion model (tflite_flutter)...');
      _interpreter = await Interpreter.fromAsset('assets/classification_emotion.tflite');

      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      print('📐 Input shape: $inputShape');  // Sẽ là [1, 640, 640, 3]
      print('📐 Output shape: $outputShape'); // Sẽ là [1, 12, 8400]
      print('✅ Model loaded successfully');

      print('📸 Reading face image...');
      final faceImage = await _loadImage(widget.faceImagePath);
      if (faceImage == null) throw Exception('Không thể đọc ảnh');

      print('🔄 Preprocessing image...');
      final input = _preprocessImage(faceImage, inputShape);

      print('🤖 Running inference...');

      // ✅ SỬA LỖI 1: TẠO ĐÚNG OUTPUT BUFFER 3D
      // Tạo một buffer có shape [1, 12, 8400]
      final output = List.generate(
        outputShape[0], // 1
            (_) => List.generate(
          outputShape[1], // 12 (4 box + 8 classes)
              (_) => List.filled(outputShape[2], 0.0), // 8400
        ),
      );

      _interpreter!.run(input, output);
      print('📊 Inference complete. Processing output...');

      // ✅ SỬA LỖI 2: XỬ LÝ OUTPUT 3D CỦA YOLO
      final detectionResult = _processYoloOutput(output, outputShape);

      if (detectionResult == null) {
        throw Exception('Không tìm thấy cảm xúc nào trong ảnh crop');
      }

      print('🎭 Emotion: ${detectionResult['emotion']} (${(detectionResult['confidence']! * 100).toStringAsFixed(1)}%)');

      setState(() {
        _emotion = detectionResult['emotion']!;
        _confidence = detectionResult['confidence']!;
        _isAnalyzing = false;
      });

    } catch (e) {
      print('❌ Error: $e');
      setState(() {
        _emotion = 'Error';
        _confidence = 0.0;
        _isAnalyzing = false;
      });
    }
  }

  /// ✅ HÀM MỚI: Xử lý output [1, 12, 8400] của model YOLO
  Map<String, dynamic>? _processYoloOutput(List<List<List<double>>> output, List<int> outputShape) {
    // output[0] sẽ có shape [12, 8400]
    final results = output[0];
    final numBoxes = outputShape[2]; // 8400
    final numClasses = _labels.length; // 8
    // 12 channels = 4 box (x,y,w,h) + 8 class scores

    double bestConfidence = 0.0;
    String bestEmotion = 'Neutral';

    // Duyệt qua tất cả 8400 box
    for (int i = 0; i < numBoxes; i++) {
      // Tìm class có score cao nhất *trong box này*
      double maxClassScore = 0.0;
      int maxClassIndex = -1;

      for (int c = 0; c < numClasses; c++) {
        // Lấy score của class 'c' tại box 'i'
        // Score bắt đầu từ channel thứ 4 (sau x,y,w,h)
        final score = results[4 + c][i];
        if (score > maxClassScore) {
          maxClassScore = score;
          maxClassIndex = c;
        }
      }

      // So sánh score của box này với score cao nhất đã tìm thấy
      if (maxClassScore > bestConfidence) {
        bestConfidence = maxClassScore;
        bestEmotion = _labels[maxClassIndex];
      }
    }

    if (bestConfidence > 0.25) { // Chỉ chấp nhận nếu confidence > 25%
      return {
        'emotion': bestEmotion,
        'confidence': bestConfidence,
      };
    }
    return null; // Không tìm thấy gì
  }


  Future<img.Image?> _loadImage(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      return img.decodeImage(bytes);
    } catch (e) {
      print('❌ Error loading image: $e');
      return null;
    }
  }

  List<List<List<List<double>>>> _preprocessImage(img.Image image, List<int> inputShape) {
    // inputShape là [1, height, width, channels]
    final height = inputShape[1]; // 640
    final width = inputShape[2];  // 640
    final channels = inputShape[3]; // 3

    print('🔧 Preprocessing to: ${width}x${height}x${channels}');

    final resized = img.copyResize(image, width: width, height: height);
    final processedImage = channels == 1 ? img.grayscale(resized) : resized;

    return [
      List.generate(
        height,
            (y) => List.generate(
          width,
              (x) {
            final pixel = processedImage.getPixel(x, y);
            if (channels == 1) {
              return [pixel.r / 255.0];
            } else {
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            }
          },
        ),
      ),
    ];
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Phần UI này giữ nguyên, không có lỗi
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Kết quả phân tích'),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 300,
                height: 400,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(
                    File(widget.faceImagePath),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              if (_isAnalyzing)
                Column(
                  children: const [
                    CircularProgressIndicator(color: Colors.blue),
                    SizedBox(height: 20),
                    Text(
                      'Đang phân tích cảm xúc...',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                )
              else if (_emotion == 'Error')
                const Text(
                  'Lỗi khi phân tích!',
                  style: TextStyle(color: Colors.red, fontSize: 18),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                  decoration: BoxDecoration(
                    color: _getEmotionColor(_emotion).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _getEmotionColor(_emotion).withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _getEmotionName(_emotion),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${(_confidence * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 40),
              if (!_isAnalyzing)
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}