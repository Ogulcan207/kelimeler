import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'main.dart'; // Login ekranı için
import 'game_screen.dart'; // Yeni oyun ekranı
import 'active_games_page.dart'; // Aktif oyunlar ekranı
import 'completed_games_page.dart'; // Biten oyunlar ekranı

class HomePage extends StatefulWidget {
  final String username;
  final String email;

  const HomePage({
    super.key,
    required this.username,
    required this.email,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool showModes = false;

  Future<void> startGame(BuildContext context, String mode) async {
    final response = await http.post(
      Uri.parse('http://10.0.2.2:8000/start-game'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'player1_username': widget.username,
        'player2_username': widget.username,
        'mode': mode,
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final gameId = json['game_id'];

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameScreen(
            gameId: gameId,
            mode: mode,
            username: widget.username,
          ),
        ),
      );
    } else {
      final json = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: ${json["detail"]}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(widget.username),
              accountEmail: Text(widget.email),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Colors.deepPurple, size: 40),
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple, Colors.purpleAccent],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Çıkış Yap'),
              onTap: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('Kelime Mayınları'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.purpleAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("👤 Kullanıcı: ${widget.username}", style: const TextStyle(fontSize: 18)),
                    Text("📧 E-posta: ${widget.email}", style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text("🎯 Başarı Yüzdesi: %0", style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() => showModes = !showModes),
              child: const Text('🎮 Yeni Oyun'),
            ),
            if (showModes) ...[
              const SizedBox(height: 16),
              _buildGameModeButton('Hızlı Oyun (2 Dakika)', Icons.timer, () => startGame(context, '2_min')),
              _buildGameModeButton('Hızlı Oyun (5 Dakika)', Icons.timer_10, () => startGame(context, '5_min')),
              _buildGameModeButton('Uzun Süreli (12 Saat)', Icons.access_time, () => startGame(context, '12_hour')),
              _buildGameModeButton('Uzun Süreli (24 Saat)', Icons.nightlight_round, () => startGame(context, '24_hour')),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActiveGamesPage(username: widget.username),
                  ),
                );
              },
              icon: const Icon(Icons.play_circle_fill),
              label: const Text('🕹️ Aktif Oyunlar'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CompletedGamesPage(username: widget.username),
                  ),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text('📜 Biten Oyunlar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameModeButton(String title, IconData icon, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
