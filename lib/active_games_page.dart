import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
      Uri.parse('http://192.168.1.103:8001/active-games/${widget.username}'),
    );

    if (response.statusCode == 200) {
      setState(() {
        activeGames = jsonDecode(response.body);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: Aktif oyunlar yüklenemedi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aktif Oyunlar')),
      body: ListView.builder(
        itemCount: activeGames.length,
        itemBuilder: (context, index) {
          final game = activeGames[index];
          return Card(
            child: ListTile(
              title: Text("Rakip: ${game['opponent']}"),
              subtitle: Text(
                "Sen: ${game['your_score']} - Rakip: ${game['opponent_score']}\nSıra: ${game['turn'] == 1 ? 'Sen' : 'Rakip'}",
              ),
              trailing: Text(game['mode']),
              onTap: () {
                // TODO: Oyuna yönlendir
              },
            ),
          );
        },
      ),
    );
  }
}
