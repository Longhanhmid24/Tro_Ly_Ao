// lib/emotion_data.dart
import 'package:flutter/material.dart';

class EmotionData {
  // Hàm lấy dữ liệu dựa trên kết quả cảm xúc (Ví dụ: "Happy", "Sad", "Angry")
  static Map<String, dynamic> getContent(String emotion) {
    // Chuyển về chữ thường để so sánh cho dễ
    String key = emotion.toLowerCase();

    // Dữ liệu mẫu (Bạn có thể thêm nhiều hơn)
    if (key.contains('happy') || key.contains('vui')) {
      return {
        'quote': "Hãy lan tỏa nụ cười của bạn, nó là tia nắng trong ngày u ám!",
        'color': Colors.yellow,
        'songTitle': "Pharrell Williams - Happy",
        'songUrl': "https://www.youtube.com/watch?v=ZbZSe6N_BXs", // Link Youtube
      };
    } else if (key.contains('sad') || key.contains('buồn')) {
      return {
        'quote': "Sau cơn mưa trời lại sáng. Hãy nghỉ ngơi một chút nhé!",
        'color': Colors.blueGrey,
        'songTitle': "Nhạc Lofi Chill Chữa Lành",
        'songUrl': "https://www.youtube.com/watch?v=jfKfPfyJRdk",
      };
    } else if (key.contains('angry') || key.contains('tức') || key.contains('giận')) {
      return {
        'quote': "Hít thở sâu... Giữ bình tĩnh là sức mạnh thực sự.",
        'color': Colors.redAccent,
        'songTitle': "Nhạc Thiền Tịnh Tâm",
        'songUrl': "https://www.youtube.com/watch?v=2OEL4P1Rz04",
      };
    } else {
      // Mặc định (Bình thường hoặc Neutral)
      return {
        'quote': "Chúc bạn một ngày bình yên và tốt lành!",
        'color': Colors.green,
        'songTitle': "Nhạc Thư Giãn Nhẹ Nhàng",
        'songUrl': "https://www.youtube.com/watch?v=lTRiuFIWV54",
      };
    }
  }
}