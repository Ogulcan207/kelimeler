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
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _startChecking();
  }

  Future<void> _startChecking() async {
    while (!_isMatched && !_isCancelling) {
      await Future.delayed(const Duration(seconds: 5));
      final response = await http.get(
        Uri.parse('http://192.168.1.103:8001/check-match?username=${widget.username}&mode=${widget.mode}'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['game_id'] != null) {
          if (!mounted) return;
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

  Future<void> _cancelWaiting() async {
    setState(() {
      _isCancelling = true;
    });

    final response = await http.delete(
      Uri.parse('http://192.168.1.196:8001/cancel-pending?username=${widget.username}'), // burada düzeltildi
    );

    if (response.statusCode == 200) {
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İptal işlemi başarısız oldu.')),
      );
      setState(() {
        _isCancelling = false; // hata olursa tekrar aktif olsun
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple[100],
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Eşleşme Bekleniyor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: _cancelWaiting,
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text(
              "Rakip bekleniyor...",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _isCancelling ? null : _cancelWaiting,
              icon: const Icon(Icons.cancel),
              label: const Text('Beklemekten Vazgeç'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
