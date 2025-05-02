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
      Uri.parse('http://192.168.1.103:102/completed-games?username=${widget.username}'),
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
        title: const Text('Biten Oyunlar'),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView.builder(
        itemCount: completedGames.length,
        itemBuilder: (context, index) {
          final game = completedGames[index];
          return Card(
            margin: const EdgeInsets.all(12),
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text("Rakip: ${game['opponent']}"),
              subtitle: Text("Skor: ${game['your_score']} - ${game['opponent_score']}"),
              trailing: Text(
                game['result'] == 'win'
                    ? 'Kazandınız'
                    : game['result'] == 'lose'
                    ? 'Kaybettiniz'
                    : 'Beraberlik',
                style: TextStyle(
                  color: game['result'] == 'win'
                      ? Colors.green
                      : game['result'] == 'lose'
                      ? Colors.red
                      : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
