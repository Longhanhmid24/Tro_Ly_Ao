import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../global.dart';

class IpInputScreen extends StatefulWidget {
  final Function() onSuccess;

  const IpInputScreen({super.key, required this.onSuccess});

  @override
  State<IpInputScreen> createState() => _IpInputScreenState();
}

class _IpInputScreenState extends State<IpInputScreen> {
  TextEditingController ipCtrl = TextEditingController();
  String? errorText;
  bool loading = false;

  Future<void> checkConnection() async {
    setState(() {
      loading = true;
      errorText = null;
    });

    String ip = ipCtrl.text.trim();

    try {
      final res = await http
          .get(Uri.parse("http://$ip:8000/docs"))
          .timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        globalIP = ip;                 // 👉 LƯU IP
        widget.onSuccess();            // 👉 Vào app
      } else {
        setState(() {
          errorText = "Server phản hồi mã ${res.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        errorText = "Không thể kết nối đến FastAPI!";
      });
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nhập IP FastAPI")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: ipCtrl,
              decoration: InputDecoration(
                labelText: "Nhập IP (VD: 192.168.1.230)",
                errorText: errorText,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : checkConnection,
              child: loading
                  ? CircularProgressIndicator(color: Colors.white)
                  : const Text("Kiểm tra kết nối"),
            )
          ],
        ),
      ),
    );
  }
}
