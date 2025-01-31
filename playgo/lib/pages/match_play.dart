import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:playgo/main.dart';
import 'package:playgo/pages/home.dart';

enum Stone { none, black, white }

class Move {
  int x;
  int y;
  Stone stone;
  Move(this.x, this.y, this.stone);
}

class GoBoardMatch extends StatefulWidget {
  final int size;
  final String gameId;
  final String playerId;
  final int totalGameTime;
  const GoBoardMatch({Key? key, required this.size, required this.gameId, required this.playerId , required this.totalGameTime}) : super(key: key);

  @override
  State<GoBoardMatch> createState() => _GoMultiplayerBoardState();
}

class _GoMultiplayerBoardState extends State<GoBoardMatch> {
  late List<List<Stone>> board;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> gameStream;
  bool isPlayerTurn = false;
  int blackScore = 0;
  int whiteScore = 0;
  int blackMissedTurns = 0;
  int whiteMissedTurns = 0;
  int blackTimeLeft = 30; // Timer for black player
  int whiteTimeLeft = 30; // Timer for white player
  int gameTimeLeft = 240; // 4-minute game timer (240 seconds)
  String userName = "";
  String partnerName = '';
  Timer? _turnTimer;
  Timer? _gameTimer;

  String? player1Id;
  String? player2Id;
  String? player1Stone;
  String? player2Stone;
  String currentTurn = 'black'; // Track the current turn
  bool showTurnNotification = false;
   
  @override
  void initState() {
    super.initState();
    gameTimeLeft = widget.totalGameTime*60;
    _initializeBoard();
    gameStream = FirebaseFirestore.instance.collection('games').doc(widget.gameId).snapshots();
    _listenToGameUpdates();
    _startTurnTimer();
    _startGameTimer();
    _markPlayerAsActive();
    _initializePlayers();
  }

  void _initializeBoard() {
    board = List.generate(widget.size, (_) => List.filled(widget.size, Stone.none));

  }

  void _initializePlayers() async {
    final gameDoc = FirebaseFirestore.instance.collection('games').doc(widget.gameId);
    final gameSnapshot = await gameDoc.get();

    if (gameSnapshot.exists) {
      final data = gameSnapshot.data();
      if (data != null) {
        setState(() {
          player1Id = data['player1Id'];
          player2Id = data['player2Id'];
          player1Stone = data['player1Stone'];
          player2Stone = data['player2Stone'];
          userName = data[player1Id];
          partnerName = data[player2Id];
          currentTurn = data['currentTurn'] ?? 'black'; // Initialize currentTurn
          blackTimeLeft = data['blackTimeLeft'] ?? 30; // Initialize black timer
          whiteTimeLeft = data['whiteTimeLeft'] ?? 30; // Initialize white timer
          isPlayerTurn = (currentTurn == 'black' && widget.playerId == player1Id && player1Stone == 'black') ||
              (currentTurn == 'white' && widget.playerId == player2Id && player2Stone == 'white');
        });
      }
    }
  }

  void _listenToGameUpdates() {
    gameStream.listen((snapshot) async {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          setState(() {
            // Deserialize the board from Firestore
            final Map<String, dynamic> firestoreBoard = data['board'] ?? {};
            for (int y = 0; y < widget.size; y++) {
              for (int x = 0; x < widget.size; x++) {
                String key = '$x\_$y';
                String stone = firestoreBoard[key] ?? 'none';
                board[y][x] = stone == 'black'
                    ? Stone.black
                    : stone == 'white'
                        ? Stone.white
                        : Stone.none;
              }
            }

            // Update scores and missed turns
            blackScore = data['blackScore'] ?? 0;
            whiteScore = data['whiteScore'] ?? 0;
            blackMissedTurns = data['blackMissedTurns'] ?? 0;
            whiteMissedTurns = data['whiteMissedTurns'] ?? 0;
            blackTimeLeft = data['blackTimeLeft'] ?? 30; // Update black timer
            whiteTimeLeft = data['whiteTimeLeft'] ?? 30; // Update white timer
            currentTurn = data['currentTurn'] ?? 'black'; // Update currentTurn

            // Determine if it's the current player's turn
            isPlayerTurn = (currentTurn == 'black' && widget.playerId == player1Id && player1Stone == 'black') ||
                (currentTurn == 'white' && widget.playerId == player2Id && player2Stone == 'white');

            if (isPlayerTurn) {
              showTurnNotification = true;
              // Hide notification after 1 second
              Future.delayed(Duration(seconds: 1), () {
                if (mounted) {
                  setState(() {
                    showTurnNotification = false;
                  });
                }
              });
            }

          });
        }
      }
    });
  }

  void destroyTheScreen() {
    Navigator.pop(context);
  }

  Future<void> _markPlayerAsActive() async {
    final gameDoc = FirebaseFirestore.instance.collection('games').doc(widget.gameId);
    final gameSnapshot = await gameDoc.get();

    if (gameSnapshot.exists) {
      List<dynamic> activePlayers = gameSnapshot['activePlayers'] ?? [];

      if (!activePlayers.contains(widget.playerId)) {
        activePlayers.add(widget.playerId);
        await gameDoc.update({'activePlayers': activePlayers});
      }
    }
  }

  Future<void> _markPlayerAsInactive() async {
    final gameDoc = FirebaseFirestore.instance.collection('games').doc(widget.gameId);
    final gameSnapshot = await gameDoc.get();

    if (gameSnapshot.exists) {
      List<dynamic> activePlayers = gameSnapshot['activePlayers'] ?? [];

      activePlayers.remove(widget.playerId);
      await gameDoc.update({'activePlayers': activePlayers});

      if (activePlayers.isEmpty) {
        await FirebaseFirestore.instance.collection('games').doc(widget.gameId).delete();
      }
    }
  }

  void _startTurnTimer() {
    _turnTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (currentTurn == 'black') {
        setState(() {
          blackTimeLeft--;
        });
        if (blackTimeLeft <= 0) {
          _missTurn(); // Switch turn immediately when time runs out
        }
      } else if (currentTurn == 'white') {
        setState(() {
          whiteTimeLeft--;
        });
        if (whiteTimeLeft <= 0) {
          _missTurn(); // Switch turn immediately when time runs out
        }
      }
    });
  }

  void _startGameTimer() {

    _gameTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        gameTimeLeft--;
      });
      if (gameTimeLeft <= 0) {
        _endGameByTime(); // End the game when the 4-minute timer runs out
      }
    });
  }

  Future<void> _missTurn() async {
    final gameDoc = FirebaseFirestore.instance.collection('games').doc(widget.gameId);
    final gameSnapshot = await gameDoc.get();

    if (gameSnapshot.exists) {
      final data = gameSnapshot.data();
      if (data != null) {
        String nextTurn = currentTurn == 'black' ? 'white' : 'black';

        // Increment missed turns for the current player
        if (currentTurn == 'black') {
          blackMissedTurns++;
        } else {
          whiteMissedTurns++;
        }

        // Switch turns without resetting timer
        await gameDoc.update({
          'currentTurn': nextTurn,
          'blackMissedTurns': blackMissedTurns,
          'whiteMissedTurns': whiteMissedTurns,
        });

        // Check if the game should end due to missed turns
        if (blackMissedTurns >= 3 || whiteMissedTurns >= 3) {
          _endGameByTime();
        }
      }
    }
  }


  void _endGameByTime() async {
    _gameTimer?.cancel();
    _turnTimer?.cancel();

    // Determine winner based on missed turns, not points
    String winner;
    if (blackMissedTurns >= 3) {
      winner = 'white';
    } else if (whiteMissedTurns >= 3) {
      winner = 'black';
    } else {
      // If no missed turns, then use points
      winner = blackScore > whiteScore ? 'black' : 'white';
    }
    
    // Update game state
    await FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
      'status': 'ended',
      'winner': winner,
      'endReason': 'timeout'
    });

    _showWinnerDialog(winner);

    // Clean up game
    await Future.delayed(Duration(seconds: 5));
    await FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
      'activePlayers': [],
    });
    await FirebaseFirestore.instance.collection('games').doc(widget.gameId).delete();
  }

  void _showWinnerDialog(String winner) {
    // Determine if current player is the winner
    bool isCurrentPlayerWinner = (winner == 'black' && player1Stone == 'black' && widget.playerId == player1Id) ||
                               (winner == 'white' && player2Stone == 'white' && widget.playerId == player2Id);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isCurrentPlayerWinner 
                ? [Colors.blue.shade200, Colors.blue.shade400]
                : [Colors.grey.shade200, Colors.grey.shade400],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCurrentPlayerWinner ? Icons.emoji_events : Icons.star,
                size: 60,
                color: isCurrentPlayerWinner ? Colors.amber : Colors.grey.shade700,
              ),
              SizedBox(height: 16),
              Text(
                isCurrentPlayerWinner ? 'Victory!' : 'You Lose',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 12),
              Text(
                isCurrentPlayerWinner
                  ? 'Congratulations on your win!'
                  : 'Better luck next time!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: isCurrentPlayerWinner ? Colors.blue : Colors.grey.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  destroyTheScreen();
                },
                child: Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }



  
  void _endGame() async {
    _turnTimer?.cancel();
    _gameTimer?.cancel();

    String winner = blackMissedTurns >= 3 ? 'white' : 'black';
    
    // Update game state
    await FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
      'status': 'ended',
      'winner': winner,
      'endReason': 'missed_turns'
    });

    _showWinnerDialog(winner);

    // Clean up game
    await Future.delayed(Duration(seconds: 5));
    await FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
      'activePlayers': [],
    });
    await FirebaseFirestore.instance.collection('games').doc(widget.gameId).delete();
    info!.updateGameStatus("DeActive",player1Id!);
    info!.updateGameStatus("DeActive", player2Id!);
  }


  List<List<int>> _findGroup(int x, int y, Stone stone) {
    List<List<int>> group = [];
    List<List<int>> visited = List.generate(widget.size, (_) => List.filled(widget.size, 0));

    void dfs(int i, int j) {
      if (i < 0 || i >= widget.size || j < 0 || j >= widget.size || visited[j][i] == 1 || board[j][i] != stone) return;
      visited[j][i] = 1;
      group.add([i, j]);
      for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        dfs(i + dir[0], j + dir[1]);
      }
    }

    dfs(x, y);
    return group;
  }

  bool _hasLiberty(List<List<int>> group) {
    for (var pos in group) {
      for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        int nx = pos[0] + dir[0];
        int ny = pos[1] + dir[1];
        if (nx >= 0 && nx < widget.size && ny >= 0 && ny < widget.size && board[ny][nx] == Stone.none) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _captureStones(List<List<int>> group) async {
    final gameDoc = FirebaseFirestore.instance.collection('games').doc(widget.gameId);
    final gameSnapshot = await gameDoc.get();

    if (gameSnapshot.exists) {
      final data = gameSnapshot.data();
      if (data != null) {
        String currentTurn = data['currentTurn'] ?? 'black';

        // Update the score for the capturing player
        if (currentTurn == 'black') {
          blackScore += group.length;
        } else {
          whiteScore += group.length;
        }

        // Remove the captured stones from the board
        for (var pos in group) {
          board[pos[1]][pos[0]] = Stone.none;
        }

        // Update the board and scores in Firestore
        Map<String, String> firestoreBoard = {};
        for (int y = 0; y < widget.size; y++) {
          for (int x = 0; x < widget.size; x++) {
            String key = '$x\_$y';
            firestoreBoard[key] = board[y][x] == Stone.black
                ? 'black'
                : board[y][x] == Stone.white
                    ? 'white'
                    : 'none';
          }
        }

        await gameDoc.update({
          'board': firestoreBoard,
          'blackScore': blackScore,
          'whiteScore': whiteScore,
        });
      }
    }
  }

  Future<void> _placeStone(int x, int y) async {
    final gameDoc = FirebaseFirestore.instance.collection('games').doc(widget.gameId);
    final gameSnapshot = await gameDoc.get();

    if (gameSnapshot.exists) {
      final data = gameSnapshot.data();
      if (data != null) {
        String currentTurn = data['currentTurn'] ?? 'black';

        if ((currentTurn == 'black' && widget.playerId == player1Id) ||
            (currentTurn == 'white' && widget.playerId == player2Id)) {
          if (board[y][x] != Stone.none) return; // Cell is already occupied

          setState(() {
            board[y][x] = currentTurn == 'black' ? Stone.black : Stone.white;
            if (currentTurn == 'black') {
              blackTimeLeft = 30;
            } else {
              whiteTimeLeft = 30;
            }

          });
          

          // Check for captures
          Stone opponent = currentTurn == 'black' ? Stone.white : Stone.black;
          for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
            int nx = x + dir[0];
            int ny = y + dir[1];
            if (nx >= 0 && nx < widget.size && ny >= 0 && ny < widget.size && board[ny][nx] == opponent) {
              var opponentGroup = _findGroup(nx, ny, opponent);
              if (!_hasLiberty(opponentGroup)) {
                await _captureStones(opponentGroup);
              }
            }
          }

          // Convert the board to a map for Firestore
          Map<String, String> firestoreBoard = {};
          for (int y = 0; y < widget.size; y++) {
            for (int x = 0; x < widget.size; x++) {
              String key = '$x\_$y';
              firestoreBoard[key] = board[y][x] == Stone.black
                  ? 'black'
                  : board[y][x] == Stone.white
                      ? 'white'
                      : 'none';
            }
          }

          // Switch turns
          String nextTurn = currentTurn == 'black' ? 'white' : 'black';
          await gameDoc.update({
            'board': firestoreBoard,
            'currentTurn': nextTurn, // Switch turns
            'blackTimeLeft': blackTimeLeft, // Update black timer
            'whiteTimeLeft': whiteTimeLeft, // Update white timer
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _turnTimer?.cancel();
    _gameTimer?.cancel();
    _markPlayerAsInactive();
    super.dispose();
  }

// [Previous imports and class definitions remain the same until build method]

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 253, 192, 100),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 253, 192, 100),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Go Multiplayer',
              style: TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
            ),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '${gameTimeLeft ~/ 60}:${(gameTimeLeft % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          double boardSize = constraints.maxWidth > constraints.maxHeight - 160 
              ? constraints.maxHeight - 160 
              : constraints.maxWidth;
          double padding = boardSize * 0.05;
          boardSize -= padding * 2;
          double cellSize = boardSize / (widget.size - 1);
          double stoneSize = cellSize * 0.8;

          return Column(
            children: [

              SizedBox(height: 8),
              _buildPlayerInfo(
                name: userName,
                score: blackScore,
                isBlack: player1Stone == 'black',
                timeLeft: player1Stone == 'black' ? blackTimeLeft : whiteTimeLeft,
                isCurrentTurn: currentTurn == (player1Stone == 'black' ? 'black' : 'white'),
              ),
              SizedBox(height: 4),
              
              // Board Container with Turn Notification Overlay
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Board
                    Center(
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Container(
                              width: boardSize + padding * 2,
                              height: boardSize + padding * 2,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD3B07C),
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            // Grid lines
                            ...List.generate(widget.size, (i) => 
                              Positioned(
                                top: i * cellSize + padding,
                                left: padding,
                                child: Container(
                                  width: boardSize,
                                  height: 1,
                                  color: Colors.black.withOpacity(0.7),
                                ),
                              ),
                            ),
                            ...List.generate(widget.size, (i) => 
                              Positioned(
                                left: i * cellSize + padding,
                                top: padding,
                                child: Container(
                                  width: 1,
                                  height: boardSize,
                                  color: Colors.black.withOpacity(0.7),
                                ),
                              ),
                            ),
                            // Stones
                            ...List.generate(
                              widget.size * widget.size,
                              (index) {
                                int x = index % widget.size;
                                int y = index ~/ widget.size;
                                if (board[y][x] != Stone.none) {
                                  return Positioned(
                                    top: y * cellSize + padding - stoneSize / 2,
                                    left: x * cellSize + padding - stoneSize / 2,
                                    child: _buildStone(board[y][x], stoneSize),
                                  );
                                }
                                return SizedBox.shrink();
                              },
                            ),
                            // Touch Grid
                            Positioned.fill(
                              child: GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: widget.size,
                                ),
                                itemCount: widget.size * widget.size,
                                itemBuilder: (context, index) {
                                  int x = index % widget.size;
                                  int y = index ~/ widget.size;
                                  return GestureDetector(
                                    onTap: () {
                                      if (isPlayerTurn) {
                                        _placeStone(x, y);
                                      }
                                    },
                                    child: Container(color: Colors.transparent),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Turn Notification Overlay (centered on board)
                    if (isPlayerTurn && showTurnNotification)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'Your Turn!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              SizedBox(height: 4),
              _buildPlayerInfo(
                name: partnerName,
                score: whiteScore,
                isBlack: player2Stone == 'black',
                timeLeft: player2Stone == 'black' ? blackTimeLeft : whiteTimeLeft,
                isCurrentTurn: currentTurn == (player2Stone == 'black' ? 'black' : 'white'),
              ),
              SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlayerInfo({
    required String name,
    required int score,
    required bool isBlack,
    required int timeLeft,
    required bool isCurrentTurn,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCurrentTurn ? Colors.blue : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: CircularProgressIndicator(
                      value: timeLeft / 30,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isCurrentTurn ? Colors.blue : Colors.grey,
                      ),
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isBlack ? Colors.black : Colors.white,
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12),
              Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Score: $score',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStone(Stone stone, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: stone == Stone.black ? Colors.black : Colors.white,
        border: Border.all(color: Colors.black.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }
}