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
  }

  Future<void> fetchBoard() async {
    final response = await http.get(
      Uri.parse('http://192.168.1.196:8001/start-board/${widget.gameId}'),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded.containsKey('board')) {
        List<Map<String, dynamic>> rawBoard = List<Map<String, dynamic>>.from(decoded['board']);

        // ✅ BURAYA EKLE
        rawBoard.sort((a, b) {
          int aIndex = a['row'] * 15 + a['col'];
          int bIndex = b['row'] * 15 + b['col'];
          return aIndex.compareTo(bIndex);
        });

        setState(() {
          boardData = rawBoard;
          isLoading = false;
        });
      } else {
        print("⚠️ Beklenmeyen veri formatı: $decoded");
      }
    } else {
      throw Exception('Tahta verisi alınamadı');
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
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.deepPurple.shade100,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('👤 ${widget.username}', style: const TextStyle(fontSize: 16)),
          const Text('Kalan Harf: 93', style: TextStyle(fontSize: 16)),
          const Text('🎯 Başarı: 0%', style: TextStyle(fontSize: 16)),
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
          // ✅ Hücrede harf varsa ve mayın varsa: resmi göster (patladı)
          if (special != null && isHiddenMine(special)) {
            final imagePath = 'assets/images/$special.png';
            content = Image.asset(
              imagePath,
              width: 40,
              height: 40,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.error, size: 16);
              },
            );
          } else {
            // ✅ Sadece harf varsa
            content = Text(
              letter,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.black,
              ),
            );
          }
        } else if (special != null && !isHiddenMine(special)) {
          // ✅ Bonus (h2, h3, k2, k3) gibi her zaman görünenleri göster
          final imagePath = 'assets/images/$special.png';
          content = Image.asset(
            imagePath,
            width: 40,
            height: 40,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.error, size: 16);
            },
          );
        } else {
          // ✅ Boş hücre
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
            onPressed: () {
              // TODO: Pas geç
            },
            icon: const Icon(Icons.skip_next),
            label: const Text('Pas'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Teslim ol
            },
            icon: const Icon(Icons.flag),
            label: const Text('Teslim Ol'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
}
