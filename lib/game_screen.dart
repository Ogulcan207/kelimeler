import 'package:flutter/material.dart';

class GameScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Oyun #$gameId - Mod: $mode'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          // 🧾 Üst Bilgiler
          Container(
            color: Colors.deepPurple.shade100,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('👤 $username', style: const TextStyle(fontSize: 16)),
                const Text('Kalan Harf: 93', style: TextStyle(fontSize: 16)),
                const Text('🎯 Başarı: 0%', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),

          // 🧩 Placeholder for board
          Expanded(
            child: Center(
              child: Text(
                'Tahta burada gösterilecek',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
            ),
          ),

          // ✅ Pas / Teslim butonları
          Padding(
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
          )
        ],
      ),
    );
  }
}
