import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GameScreen extends StatefulWidget {
  final int gameId;
  final String mode;
  final String username;

  const GameScreen({
    super.key,
    required this.gameId,
    required this.mode,
    required this.username,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  List<Map<String, dynamic>> boardData = [];
  bool isLoading = true;
  int player1Score = 0;
  int player2Score = 0;
  int currentTurn = 1;
  String opponent = "";

  bool isHiddenMine(String? type) {
    return [
      'puan_bolunmesi',
      'puan_transferi',
      'harf_kaybi',
      'ekstra_hamle_engeli',
      'kelime_iptali',
      'bolge_yasagi',
      'harf_yasagi',
      'ekstra_hamle_jokeri'
    ].contains(type);
  }

  @override
  void initState() {
    super.initState();
    fetchBoard();
    fetchGameInfo();
    Future.delayed(const Duration(seconds: 10), checkGameStillActive);
  }

  void checkGameStillActive() async {
    await fetchGameInfo(); // süre dolduysa otomatik geri döner
    Future.delayed(const Duration(seconds: 10), checkGameStillActive);
  }

  Future<void> fetchGameInfo() async {
    final response = await http.get(
      Uri.parse('http://192.168.1.102:8001/get_active_games_by_user/${widget.username}'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      bool gameFound = false;
      for (var game in data) {
        if (game['id'] == widget.gameId) {
          setState(() {
            player1Score = game['player1_score'];
            player2Score = game['player2_score'];
            currentTurn = game['current_turn'];
            opponent = game['opponent'];
          });
          gameFound = true;
          break;
        }
      }

      // Oyun bulunamadıysa yani süre dolduysa (backend artık getirmiyorsa)
      if (!gameFound) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⏰ Oyun süresi doldu veya tamamlandı.")),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> fetchBoard() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.102:8001/start-board/${widget.gameId}'),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('board')) {
          List<Map<String, dynamic>> rawBoard = List<Map<String, dynamic>>.from(decoded['board']);

          rawBoard.sort((a, b) {
            int aIndex = a['row'] * 15 + a['col'];
            int bIndex = b['row'] * 15 + b['col'];
            return aIndex.compareTo(bIndex);
          });

          setState(() {
            boardData = rawBoard;
            isLoading = false;
          });
        }
      } else {
        throw Exception('Tahta verisi alınamadı');
      }
    } catch (e) {
      print('Hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Oyun #${widget.gameId} - Mod: ${widget.mode}'),
        backgroundColor: Colors.deepPurple,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 2.5,
              child: _buildBoardGrid(),
            ),
          ),
          _buildBottomButtons(),
          _buildLetterRack(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.deepPurple.shade100,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('👤 Sen: ${widget.username}', style: const TextStyle(fontSize: 16)),
              Text('🆚 Rakip: $opponent', style: const TextStyle(fontSize: 16)),
              Text('🎯 Tur: ${currentTurn == 1 ? "1" : "2"}', style: const TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('📊 Senin Skorun: $player1Score', style: const TextStyle(fontSize: 14)),
              Text('📊 Rakip Skoru: $player2Score', style: const TextStyle(fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBoardGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 15,
      ),
      itemCount: boardData.length,
      itemBuilder: (context, index) {
        final cell = boardData[index];
        final letter = cell['letter'];
        final special = cell['special_type'];

        Widget content;

        if (letter != null) {
          if (special != null && isHiddenMine(special)) {
            content = Image.asset('assets/images/$special.png', width: 40, height: 40, errorBuilder: (_, __, ___) => const Icon(Icons.error, size: 16));
          } else {
            content = Text(letter, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22));
          }
        } else if (special != null && !isHiddenMine(special)) {
          content = Image.asset('assets/images/$special.png', width: 40, height: 40, errorBuilder: (_, __, ___) => const Icon(Icons.error, size: 16));
        } else {
          content = const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(1),
          color: Colors.grey.shade200,
          child: Center(child: content),
        );
      },
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: passTurn,
            icon: const Icon(Icons.skip_next),
            label: const Text('Pas'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
          ),
          ElevatedButton.icon(
            onPressed: surrenderGame,
            icon: const Icon(Icons.flag),
            label: const Text('Teslim Ol'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  Future<void> passTurn() async {
    final response = await http.post(
      Uri.parse('http://192.168.1.102:8001/pass-turn'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'game_id': widget.gameId,
        'username': widget.username,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));
      fetchGameInfo(); // sırayı güncelle
    } else {
      final error = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: ${error['detail']}')));
    }
  }

  Future<void> surrenderGame() async {
    final response = await http.post(
      Uri.parse('http://192.168.1.102:8001/surrender'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'game_id': widget.gameId,
        'username': widget.username,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Oyun bitti. Kazanan: ${data['winner']}')));
      Navigator.pop(context); // anasayfaya dön
    } else {
      final error = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: ${error['detail']}')));
    }
  }

  Widget _buildLetterRack() {
    return FutureBuilder<http.Response>(
      future: http.get(Uri.parse('http://192.168.1.102:8001/get-letters/${widget.gameId}/${widget.username}')),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError || snapshot.data == null || snapshot.data!.statusCode != 200) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Harfler yüklenemedi'),
          );
        }

        final decoded = jsonDecode(snapshot.data!.body);
        final letters = List<Map<String, dynamic>>.from(decoded['letters']);

        return Container(
          color: Colors.orange.shade100,
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: letters.map<Widget>((tile) {
                return Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(tile['letter'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Text('${tile['point']}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
