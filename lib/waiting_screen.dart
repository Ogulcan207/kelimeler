import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'game_screen.dart';

class WaitingScreen extends StatefulWidget {
  final String username;
  final String mode;

  const WaitingScreen({super.key, required this.username, required this.mode});

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> {
  bool _isMatched = false;

  @override
  void initState() {
    super.initState();
    _checkMatch();
  }

  Future<void> _checkMatch() async {
    while (!_isMatched) {
      await Future.delayed(const Duration(seconds: 5));
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/check-match?username=${widget.username}&mode=${widget.mode}'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['game_id'] != null) {
          setState(() {
            _isMatched = true;
          });

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => GameScreen(
                gameId: json['game_id'],
                mode: widget.mode,
                username: widget.username,
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple[100],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              "Rakip bekleniyor...",
              style: TextStyle(fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}
