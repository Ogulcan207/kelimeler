import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CompletedGamesPage extends StatefulWidget {
  final String username;

  const CompletedGamesPage({super.key, required this.username});

  @override
  State<CompletedGamesPage> createState() => _CompletedGamesPageState();
}

class _CompletedGamesPageState extends State<CompletedGamesPage> {
  List<dynamic> completedGames = [];

  @override
  void initState() {
    super.initState();
    fetchCompletedGames();
  }

  Future<void> fetchCompletedGames() async {
    final response = await http.get(
      Uri.parse('http://192.168.1.103:8001/completed-games/${widget.username}'),
    );

    if (response.statusCode == 200) {
      setState(() {
        completedGames = jsonDecode(response.body);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tamamlanan oyunlar alınamadı')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧾 Biten Oyunlar'),
        backgroundColor: Colors.deepPurple,
      ),
      body: RefreshIndicator(
        onRefresh: fetchCompletedGames,
        child: completedGames.isEmpty
            ? const Center(child: Text('Henüz biten oyun yok'))
            : ListView.builder(
          itemCount: completedGames.length,
          itemBuilder: (context, index) {
            final game = completedGames[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.sports_esports, color: Colors.deepPurple),
                title: Text("Rakip: ${game['opponent']}"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Skor: ${game['your_score']} - ${game['opponent_score']}"),
                    Text("Oyun ID: ${game['id']}"),
                  ],
                ),
                trailing: Text(
                  game['result'] == 'win'
                      ? 'Kazandınız'
                      : game['result'] == 'lose'
                      ? 'Kaybettiniz'
                      : 'Berabere',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: game['result'] == 'win'
                        ? Colors.green
                        : game['result'] == 'lose'
                        ? Colors.red
                        : Colors.orange,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
