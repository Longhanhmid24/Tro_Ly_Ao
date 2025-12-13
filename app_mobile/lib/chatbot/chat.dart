import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../global.dart';

class ChatBotScreen extends StatefulWidget {
  final String firstEmotion;
  final double confidence;

  const ChatBotScreen({
    super.key,
    required this.firstEmotion,
    required this.confidence,
  });

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> messages = [];
  bool isLoading = false;

  String get apiUrl => "http://$globalIP:8000/generate";

  @override
  void initState() {
    super.initState();
    _requestFirstBotMessage(); // 🔥 BOT NÓI CÂU ĐẦU TIÊN
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 🔥 GỬI REQUEST ẨN DỰA TRÊN CẢM XÚC YOLO
  Future<void> _requestFirstBotMessage() async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "emotion": widget.firstEmotion,
          "confidence": widget.confidence,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        messages.add({
          "role": "bot",
          "text": data["response"],
        });
      }
    } catch (_) {
      messages.add({
        "role": "bot",
        "text": "Xin lỗi, tôi chưa thể phản hồi lúc này.",
      });
    }

    setState(() => isLoading = false);
    _scrollToBottom();
  }

  /// 💬 USER GỬI TIN NHẮN BÌNH THƯỜNG
  Future<void> sendMessage(String text) async {
    setState(() {
      messages.add({"role": "user", "text": text});
      isLoading = true;
    });

    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"emotion": text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        messages.add({
          "role": "bot",
          "text": data["response"],
        });
      }
    } catch (_) {
      messages.add({
        "role": "bot",
        "text": "Không thể kết nối đến server.",
      });
    }

    setState(() => isLoading = false);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          "Trợ lý cảm xúc AI",
          style: TextStyle(color: Colors.black87),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (_, index) {
                final msg = messages[index];
                final isUser = msg["role"] == "user";

                return Align(
                  alignment:
                  isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      msg["text"]!,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                "AI đang phản hồi...",
                style: TextStyle(color: Colors.grey),
              ),
            ),

          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        hintText: "Nhập tin nhắn...",
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: isLoading
                        ? null
                        : () {
                      final text = _controller.text.trim();
                      if (text.isNotEmpty) {
                        _controller.clear();
                        sendMessage(text);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
