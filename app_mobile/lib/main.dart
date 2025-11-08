// main.dart - ĐÃ SỬA LỖI

import 'package:flutter/material.dart';
// 🔹 KHÔNG CẦN import 'package:camera/camera.dart';
import 'screen/yolo_screen.dart';

// 🔹 KHÔNG CẦN biến 'cameras'
// late List<CameraDescription> cameras;

Future<void> main() async {
  // 🔹 Vẫn cần dòng này
  WidgetsFlutterBinding.ensureInitialized();

  // 🔹 KHÔNG CẦN khởi tạo camera ở đây
  // cameras = await availableCameras();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "AI Virtual Assistant",
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const HomeScreen(), // 🔹 Bắt đầu với HomeScreen
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: GestureDetector(
          onTap: () {
            // 🔹 CHỈ CẦN ĐIỀU HƯỚNG
            Navigator.push(
              context,
              MaterialPageRoute(
                // 🔹 Gọi YoloScreen() mà không cần tham số
                builder: (context) => const YoloScreen(),
              ),
            );
          },
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.6),
                  blurRadius: 50,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/ai_button.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }
}