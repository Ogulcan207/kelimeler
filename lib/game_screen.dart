import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:collection/collection.dart';

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

class PlacedLetter {
  final int row;
  final int col;
  final String letter;

  PlacedLetter({required this.row, required this.col, required this.letter});

  Map<String, dynamic> toJson() => {
    "row": row,
    "col": col,
    "letter": letter, // <-- bu eksik!
  };
}

class _GameScreenState extends State<GameScreen> {
  List<Map<String, dynamic>> boardData = [];
  bool isLoading = true;
  int player1Score = 0;
  int player2Score = 0;
  int currentTurn = 1;
  String opponent = "";
  String timeLeft = "";
  DateTime? endTime;
  Timer? countdownTimer;
  bool gameEnded = false;
  String? selectedLetter;
  int? selectedLetterIndex;
  List<PlacedLetter> placedLetters = [];
  Set<String> validWords = {};
  String currentWord = '';
  int predictedScore = 0;
  bool isValid = false;
  Set<int> usedLetterIndices = {};
  List<Map<String, dynamic>> currentLetters = []; // <-- Harf listesini global tut

  @override
  void initState() {
    super.initState();
    fetchBoard();
    fetchGameInfo();
    loadValidWords();
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }

  bool isHiddenMine(String? type) {
    return [
      'puan_bolunmesi', 'puan_transferi', 'harf_kaybi',
      'ekstra_hamle_engeli', 'kelime_iptali', 'bolge_yasagi',
      'harf_yasagi', 'ekstra_hamle_jokeri'
    ].contains(type);
  }

  Future<void> loadValidWords() async {
    final wordsString = await DefaultAssetBundle.of(context).loadString('assets/turkce_kelime_listesi.txt');
    final lines = wordsString.split('\n');
    setState(() {
      validWords = lines.map((e) => e.trim().toUpperCase()).toSet();
    });
  }

  Future<void> fetchGameInfo() async {
    final response = await http.get(
      Uri.parse('http://192.168.1.103:8001/get_active_games_by_user/${widget.username}'),
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
            endTime = DateTime.parse(game['end_time']);
          });
          startCountdownTimer();
          gameFound = true;
          break;
        }
      }
      if (!gameFound) {
        showGameOverDialog("Oyun süresi doldu.");
      }
    }
  }

  void startCountdownTimer() {
    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (endTime == null || gameEnded) return;

      // Güncel oyun bilgilerini tekrar çek
      final response = await http.get(
        Uri.parse('http://192.168.1.103:8001/get_active_games_by_user/${widget.username}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Map<String, dynamic>> games = List<Map<String, dynamic>>.from(data);
        final activeGame = games.firstWhereOrNull((game) => game['id'] == widget.gameId);

        if (activeGame == null || activeGame['is_active'] == false) {
          timer.cancel();
          showGameOverDialog("Oyun sona erdi.");
          return;
        }

        setState(() {
          endTime = DateTime.parse(activeGame['end_time']);
          player1Score = activeGame['player1_score'];
          player2Score = activeGame['player2_score'];
          currentTurn = activeGame['current_turn'];
          opponent = activeGame['opponent'];
        });

        fetchBoard();

        final diff = endTime!.difference(DateTime.now());
        if (diff.isNegative) {
          timer.cancel();
          showGameOverDialog("Süre doldu.");
        } else {
          final m = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
          final s = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
          setState(() {
            timeLeft = "$m:$s";
          });
        }
      }
    });
  }

  Future<void> showGameOverDialog(String message) async {
    gameEnded = true;
    String winner;

    bool isPlayer1 = currentTurn == 1 && opponent != widget.username;

    if ((isPlayer1 && player1Score > player2Score) ||
        (!isPlayer1 && player2Score > player1Score)) {
      winner = "${widget.username} kazandı!";
    } else if ((isPlayer1 && player2Score > player1Score) ||
        (!isPlayer1 && player1Score > player2Score)) {
      winner = "$opponent kazandı!";
    } else {
      winner = "Berabere!";
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("🏁 Oyun Bitti"),
        content: Text("$message\n\nKazanan: $winner\nSen: $player1Score\nRakip: $player2Score"),
      ),
    );

    await Future.delayed(const Duration(seconds: 5));
    if (mounted) {
      Navigator.of(context).pop(); // dialog
      Navigator.of(context).pop(); // geri
    }
  }

  Future<void> fetchBoard() async {
    final response = await http.get(
      Uri.parse('http://192.168.1.103:8001/start-board/${widget.gameId}'),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded.containsKey('board')) {
        List<Map<String, dynamic>> rawBoard = List<Map<String, dynamic>>.from(decoded['board']);
        rawBoard.sort((a, b) => (a['row'] * 15 + a['col']).compareTo(b['row'] * 15 + b['col']));
        setState(() {
          boardData = rawBoard;
          isLoading = false;
        });
      }
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
              Text('🕒 Kalan: $timeLeft', style: const TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 6),
          // ✅ Kelime ve doğruluk rengi göstergesi
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              currentWord.isEmpty ? 'Kelime Oluşturun' : currentWord,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: currentWord.isEmpty
                    ? Colors.black
                    : (isValid ? Colors.green : Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void updateCurrentWordAndValidation() {

    if (validWords.isEmpty) return; // Henüz yüklenmemişse boşuna kontrol yapma

    currentWord = placedLetters.map((e) => e.letter).join();
    isValid = validWords.contains(currentWord.toUpperCase());
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
        final row = cell['row'];
        final col = cell['col'];
        final letter = cell['letter'];
        final special = cell['special_type'];

        final placed = placedLetters.firstWhereOrNull((pl) => pl.row == row && pl.col == col);

        Widget content;

        if (placed != null) {
          content = Text(placed.letter, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold));
        } else if (letter != null) {
          if (special != null && isHiddenMine(special)) {
            content = Image.asset('assets/images/$special.png', width: 40, height: 40, errorBuilder: (_, __, ___) => const Icon(Icons.error));
          } else {
            content = Text(letter, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22));
          }
        } else if (special != null && !isHiddenMine(special)) {
          content = Image.asset(
            'assets/images/$special.png',
            width: 40,
            height: 40,
            errorBuilder: (_, __, ___) => const Icon(Icons.error),
          );
        } else {
          content = const SizedBox.shrink(); // boş hücre
        }

        return GestureDetector(
          onTap: () {
            setState(() {
              if (placed != null) {
                // Geri alma
                placedLetters.removeWhere((pl) => pl.row == row && pl.col == col);

                for (int i = 0; i < currentLetters.length; i++) {
                  if (currentLetters[i]['letter'] == placed.letter && usedLetterIndices.contains(i)) {
                    usedLetterIndices.remove(i);
                    break;
                  }
                }

                updateCurrentWordAndValidation();
              } else if (selectedLetter != null && letter == null) {
                placedLetters.add(PlacedLetter(row: row, col: col, letter: selectedLetter!));
                usedLetterIndices.add(selectedLetterIndex!);
                selectedLetter = null;
                selectedLetterIndex = null;
                updateCurrentWordAndValidation();
              }
            });
          },
          child: Container(
            margin: const EdgeInsets.all(1),
            color: Colors.grey.shade200,
            child: Center(child: content),
          ),
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
          ElevatedButton.icon(
            onPressed: placedLetters.isEmpty ? null : submitMove,
            icon: const Icon(Icons.check),
            label: const Text("Hamleyi Bitir"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  Future<void> passTurn() async {
    final response = await http.post(
      Uri.parse('http://192.168.1.103:8001/pass-turn'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'game_id': widget.gameId, 'username': widget.username}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      fetchGameInfo();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));
      fetchGameInfo(); // sırayı güncelle
    } else {
      final error = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: ${error['detail']}')));
    }
  }

  Future<void> surrenderGame() async {
    final response = await http.post(
      Uri.parse('http://192.168.1.103:8001/surrender'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'game_id': widget.gameId, 'username': widget.username}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      showGameOverDialog("Teslim oldun. Kazanan: ${data['winner']}");
    } else {
      final error = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: ${error['detail']}')));
    }
  }

  Future<void> submitMove() async {
    final response = await http.post(
      Uri.parse('http://192.168.1.103:8001/play-move'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "game_id": widget.gameId,
        "username": widget.username,
        "word": placedLetters.map((e) => e.letter).join(),
        "positions": placedLetters.map((e) => e.toJson()).toList(),
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hamle gönderildi')));
      fetchBoard();
      fetchGameInfo();
      setState(() {
        placedLetters.clear();
        selectedLetter = null;
        selectedLetterIndex = null;
        usedLetterIndices.clear(); // <-- BUNU EKLE
      });
    } else {
      final error = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: ${error['detail']}')));
    }
  }

  Widget _buildLetterRack() {
    return FutureBuilder<http.Response>(
      future: http.get(Uri.parse('http://192.168.1.103:8001/get-letters/${widget.gameId}/${widget.username}')),
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

        currentLetters = letters; // <<< GLOBAL değişkene atandı

        return Container(
          color: Colors.orange.shade100,
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(letters.length, (index) {
                final tile = letters[index];
                final isSelected = selectedLetterIndex == index;

                return GestureDetector(
                  onTap: () {
                    if (!usedLetterIndices.contains(index)) {
                      setState(() {
                        selectedLetter = tile['letter'];
                        selectedLetterIndex = index;
                      });
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(6),
                      border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
                    ),
                    child: Center(
                      child: FittedBox(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(tile['letter'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            Text('${tile['point']}', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}