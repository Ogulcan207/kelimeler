import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PendingGamesPage extends StatefulWidget {
  final String username;

  const PendingGamesPage({super.key, required this.username});

  @override
  State<PendingGamesPage> createState() => _PendingGamesPageState();
}

class _PendingGamesPageState extends State<PendingGamesPage> {
  List<dynamic> pendingGames = [];

  @override
  void initState() {
    super.initState();
    fetchPendingGames();
  }

  Future<void> fetchPendingGames() async {
    final response = await http.get(
      Uri.parse('http://192.168.1.102:8001/all-pending-games'),
    );

    if (response.statusCode == 200) {
      setState(() {
        pendingGames = jsonDecode(response.body);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: Bekleyen oyunlar yüklenemedi')),
      );
    }
  }

  Future<void> joinPendingGame(int pendingId) async {
    final response = await http.post(
      Uri.parse('http://192.168.1.102:8001/join-pending-game'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'pending_id': pendingId, 'username': widget.username}),
    );

    if (response.statusCode == 200) {
      Navigator.pop(context); // Başarılı olunca geri dön
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
      appBar: AppBar(
        title: const Text('Bekleyen Oyunlar'),
        backgroundColor: Colors.deepPurple,
      ),
      body: pendingGames.isEmpty
          ? const Center(child: Text('Şu anda bekleyen oyun yok.'))
          : ListView.builder(
        itemCount: pendingGames.length,
        itemBuilder: (context, index) {
          final pending = pendingGames[index];
          final isMyGame = pending['username'] == widget.username;

          return Card(
            child: ListTile(
              title: Text("${pending['username']} - ${pending['mode']}"),
              trailing: isMyGame
                  ? const Text('Bekleniyor...')
                  : ElevatedButton(
                onPressed: () => joinPendingGame(pending['id']),
                child: const Text('Katıl'),
              ),
            ),
          );
        },
      ),
    );
  }
}
