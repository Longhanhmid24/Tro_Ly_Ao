// lib/screen/emotion_result_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:app_mobile/chatbot/chat.dart';

// --- THÊM 2 IMPORT MỚI ---
import 'package:url_launcher/url_launcher.dart'; // Để mở link nhạc
import '../emotion_data.dart'; // Để lấy dữ liệu lời khuyên & nhạc
// -------------------------

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

  // --- BIẾN MỚI CHO TÍNH NĂNG GIẢI TRÍ ---
  String _quote = '';
  String _songTitle = '';
  String _songUrl = '';
  Color _themeColor = Colors.blue;
  // ---------------------------------------

  Interpreter? _interpreter;

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

  @override
  void initState() {
    super.initState();
    _loadModelAndAnalyze();
  }

  /// Hàm mở link nhạc
  Future<void> _launchMusicUrl() async {
    if (_songUrl.isEmpty) return;
    
    final Uri url = Uri.parse(_songUrl);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $_songUrl');
      }
    } catch (e) {
      print("Lỗi mở link: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở bài hát này!')),
      );
    }
  }

  Future<void> _loadModelAndAnalyze() async {
    setState(() => _isAnalyzing = true);

    try {
      print('📦 Loading emotion model...');
      _interpreter = await Interpreter.fromAsset('assets/classification_emotion.tflite');

      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;

      final faceImage = await _loadImage(widget.faceImagePath);
      if (faceImage == null) throw Exception('Không thể đọc ảnh');

      final input = _preprocessImage(faceImage, inputShape);

      // Tạo buffer output
      final output = List.generate(
        outputShape[0],
        (_) => List.generate(
          outputShape[1],
          (_) => List.filled(outputShape[2], 0.0),
        ),
      );

      _interpreter!.run(input, output);

      final detectionResult = _processYoloOutput(output, outputShape);

      if (detectionResult == null) {
        throw Exception('Không tìm thấy cảm xúc nào rõ ràng');
      }

      // --- CẬP NHẬT DỮ LIỆU TỪ EMOTION_DATA ---
      final emotionKey = detectionResult['emotion']!;
      final content = EmotionData.getContent(emotionKey);
      // ----------------------------------------

      setState(() {
        _emotion = emotionKey;
        _confidence = detectionResult['confidence']!;
        
        // Cập nhật thông tin giải trí
        _quote = content['quote'];
        _songTitle = content['songTitle'];
        _songUrl = content['songUrl'];
        _themeColor = content['color'];

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

  // --- GIỮ NGUYÊN LOGIC XỬ LÝ MODEL CỦA BẠN ---
  Map<String, dynamic>? _processYoloOutput(List<List<List<double>>> output, List<int> outputShape) {
    final results = output[0];
    final numBoxes = outputShape[2];
    final numClasses = _labels.length;

    double bestConfidence = 0.0;
    String bestEmotion = 'Neutral';

    for (int i = 0; i < numBoxes; i++) {
      double maxClassScore = 0.0;
      int maxClassIndex = -1;

      for (int c = 0; c < numClasses; c++) {
        final score = results[4 + c][i];
        if (score > maxClassScore) {
          maxClassScore = score;
          maxClassIndex = c;
        }
      }

      if (maxClassScore > bestConfidence) {
        bestConfidence = maxClassScore;
        bestEmotion = _labels[maxClassIndex];
      }
    }

    if (bestConfidence > 0.10) {
      return {
        'emotion': bestEmotion,
        'confidence': bestConfidence,
      };
    }
    return null;
  }

  Future<img.Image?> _loadImage(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      return img.decodeImage(bytes);
    } catch (e) {
      return null;
    }
  }

  List<List<List<List<double>>>> _preprocessImage(img.Image image, List<int> inputShape) {
    final height = inputShape[1];
    final width = inputShape[2];
    final channels = inputShape[3];

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
              
              // Ảnh chụp
              Container(
                width: 250, // Thu nhỏ lại chút cho đẹp
                height: 330,
                decoration: BoxDecoration(
                  border: Border.all(color: _isAnalyzing ? Colors.white : _themeColor, width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: Image.file(
                    File(widget.faceImagePath),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              
              const SizedBox(height: 30),

              if (_isAnalyzing)
                const Column(
                  children: [
                    CircularProgressIndicator(color: Colors.blue),
                    SizedBox(height: 15),
                    Text('Đang đọc vị cảm xúc...', style: TextStyle(color: Colors.white70)),
                  ],
                )
              else if (_emotion == 'Error')
                const Text('Có lỗi xảy ra', style: TextStyle(color: Colors.red))
              else
                Column(
                  children: [
                    // --- KHUNG KẾT QUẢ + QUOTE ---
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _themeColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _themeColor, width: 1),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _getEmotionName(_emotion).toUpperCase(),
                            style: TextStyle(
                              color: _themeColor,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'Độ tin cậy: ${(_confidence * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                          const Divider(color: Colors.white24, height: 30),
                          
                          // Hiển thị Lời khuyên (Quote)
                          Text(
                            '"$_quote"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // --- NÚT NGHE NHẠC ---
                    GestureDetector(
                      onTap: _launchMusicUrl,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.grey.shade900, Colors.black],
                          ),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white24),
                          boxShadow: [
                            BoxShadow(color: _themeColor.withOpacity(0.3), blurRadius: 10)
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.music_note, color: _themeColor, size: 30),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Gợi ý bài hát:",
                                    style: TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                  Text(
                                    _songTitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.play_circle_fill, color: Colors.white, size: 30),
                          ],
                        ),
                      ),
                    ),
                    // ---------------------

                    const SizedBox(height: 30),

                    // Các nút chức năng cũ
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade800,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 15),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatBotScreen(
                                  firstEmotion: _emotion,
                                  confidence: _confidence,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.smart_toy),
                          label: const Text('Tâm sự AI'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _themeColor, // Nút đổi màu theo cảm xúc
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}