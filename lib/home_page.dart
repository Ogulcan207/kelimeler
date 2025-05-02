import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'main.dart';
import 'game_screen.dart';
import 'active_games_page.dart';
import 'completed_games_page.dart';
import 'waiting_screen.dart';
import 'pending_games_page.dart'; // Bekleyen oyunlar sayfası

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
      Uri.parse('http://192.168.1.102:8001/start-game'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': widget.username,
        'mode': mode,
      }),
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      if (json.containsKey('game_id')) {
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
      } else if (json.containsKey('waiting')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WaitingScreen(
              username: widget.username,
              mode: mode,
            ),
          ),
        );
      }
    } else {
      final json = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: ${json["detail"]}')),
      );
    }
  }

  Future<void> _checkMyPendingGame(BuildContext context) async {
    final response = await http.get(
      Uri.parse('http://192.168.1.102:8001/my-pending-game/${widget.username}'),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      if (json['waiting'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WaitingScreen(
              username: widget.username,
              mode: json['mode'],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bekleyen bir oyununuz bulunamadı.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sunucu hatası.')),
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
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.purpleAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("👤 Kullanıcı: ${widget.username}", style: const TextStyle(fontSize: 18)),
                      Text("📧 E-posta: ${widget.email}", style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      FutureBuilder<http.Response>(
                        future: http.get(Uri.parse('http://192.168.1.102:8001/win-stats/${widget.username}')),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState != ConnectionState.done) {
                            return const Text("🎯 Başarı Yüzdesi: %...", style: TextStyle(fontSize: 16));
                          }
                          if (snapshot.hasError || snapshot.data == null || snapshot.data!.statusCode != 200) {
                            return const Text("🎯 Başarı Yüzdesi: %Hata", style: TextStyle(fontSize: 16));
                          }
                          final stats = jsonDecode(snapshot.data!.body);
                          return Text(
                            "🎯 Başarı Yüzdesi: %${stats['win_rate']} (${stats['wins']}/${stats['played']})",
                            style: const TextStyle(fontSize: 16),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  "Oyunlar",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              _buildButton(Icons.add_circle, 'Yeni Oyun Başlat', () {
                setState(() => showModes = !showModes);
              }),
              if (showModes) ...[
                _buildGameModeButton('Hızlı Oyun (2 Dakika)', Icons.timer, () => startGame(context, 'fast_2_min')),
                _buildGameModeButton('Hızlı Oyun (5 Dakika)', Icons.timer_10, () => startGame(context, 'fast_5_min')),
                _buildGameModeButton('Uzun Süreli (12 Saat)', Icons.access_time, () => startGame(context, 'extended_12_hour')),
                _buildGameModeButton('Uzun Süreli (24 Saat)', Icons.nightlight_round, () => startGame(context, 'extended_24_hour')),
              ],
              const SizedBox(height: 16),
              _buildButton(Icons.play_circle_fill, 'Aktif Oyunlarım', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ActiveGamesPage(username: widget.username)),
                );
              }),
              _buildButton(Icons.history, 'Biten Oyunlarım', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CompletedGamesPage(username: widget.username)),
                );
              }),
              _buildButton(Icons.hourglass_empty, 'Bekleyen Oyunum', () {
                _checkMyPendingGame(context);
              }),
              _buildButton(Icons.list, 'Bekleyen Oyunlara Katıl', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PendingGamesPage(username: widget.username)),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(IconData icon, String title, VoidCallback onTap) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  Widget _buildGameModeButton(String title, IconData icon, VoidCallback onTap) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
