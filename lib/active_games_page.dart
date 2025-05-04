import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'game_screen.dart';
import 'waiting_screen.dart';

class ActiveGamesPage extends StatefulWidget {
  final String username;

  const ActiveGamesPage({super.key, required this.username});

  @override
  State<ActiveGamesPage> createState() => _ActiveGamesPageState();
}

class _ActiveGamesPageState extends State<ActiveGamesPage> {
  List<dynamic> activeGames = [];

  @override
  void initState() {
    super.initState();
    fetchActiveGames();
  }

  Future<void> fetchActiveGames() async {
    final response = await http.get(
      Uri.parse('http://192.168.1.103:8001/get_active_games_by_user/${widget.username}'),
    );

    if (response.statusCode == 200) {
      setState(() {
        activeGames = jsonDecode(response.body);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: Oyunlar yüklenemedi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aktif Oyunlar')),
      body: activeGames.isEmpty
          ? const Center(child: Text('Hiç aktif veya bekleyen oyun yok.'))
          : ListView.builder(
        itemCount: activeGames.length,
        itemBuilder: (context, index) {
          final game = activeGames[index];
          if (game['type'] == 'pending') {
            return Card(
              child: ListTile(
                title: Text("Bekleyen Oyun (${game['mode']})"),
                subtitle: const Text("Rakip aranıyor..."),
                trailing: const Icon(Icons.hourglass_empty),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WaitingScreen(
                        username: widget.username,
                        mode: game['mode'],
                      ),
                    ),
                  );
                },
              ),
            );
          } else {
            return Card(
              child: ListTile(
                title: Text("Rakip: ${game['opponent']}"),
                subtitle: Text(
                  "Sen: ${game['your_score']} - Rakip: ${game['opponent_score']}\n"
                      "Sıra: ${game['turn'] == 1 ? 'Sen' : 'Rakip'}",
                ),
                trailing: game['is_started'] == false
                    ? ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GameScreen(
                          gameId: game['id'],
                          mode: game['mode'],
                          username: widget.username,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text("Oyunu Başlat"),
                )
                    : Text(game['mode'], style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GameScreen(
                        gameId: game['id'],
                        mode: game['mode'],
                        username: widget.username,
                      ),
                    ),
                  );
                },
              ),
            );

          }
        },
      ),
    );
  }
}
