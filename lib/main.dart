import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: RoomSelectionScreen(),
    );
  }
}

class RoomSelectionScreen extends StatelessWidget {
  final TextEditingController _roomController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select a Room'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _roomController,
              decoration: InputDecoration(
                labelText: 'Enter Room Name',
              ),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () {
                final roomName = _roomController.text;
                if (roomName.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(roomName: roomName),
                    ),
                  );
                }
              },
              child: Text('Join Room'),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String roomName;

  const ChatScreen({Key? key, required this.roomName}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  ServerSocket? server;
  List<Socket> clients = [];
  TextEditingController _messageController = TextEditingController();
  List<String> messages = [];

  @override
  void initState() {
    super.initState();
    initNetwork();
    initDatabase();
  }

  Future<void> initDatabase() async {
    final database = await createDatabase();
    print('Database initialized.');

    // Load messages from the database when the app starts.
    await loadMessages();
  }

  Future<Database> createDatabase() async {
    final databaseFolder = await getDatabasesPath();
    return openDatabase(
      join(databaseFolder, '${widget.roomName}_chat_database.db'),
      onCreate: (db, version) {
        db.execute(
          'CREATE TABLE messages (id INTEGER PRIMARY KEY, sender TEXT, message TEXT, timestamp INTEGER)',
        );
      },
      version: 1,
    );
  }

  Future<void> initNetwork() async {
    try {
      server = await ServerSocket.bind('0.0.0.0', 12345);
      server?.listen((Socket clientSocket) {
        setState(() {
          clients.add(clientSocket);
        });
        clientSocket.listen(
          (List<int> data) {
            final receivedMessage = utf8.decode(data);
            handleReceivedMessage(receivedMessage);
          },
          onDone: () {
            print('Client disconnected');
            handleClientDisconnect(clientSocket);
          },
        );
      });
    } catch (e) {
      print('Failed to create server: $e');
    }
  }

  Future<void> insertMessage(String sender, String message) async {
    final database = await createDatabase();
    await database.insert(
      'messages',
      {
        'sender': sender,
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Reload messages after inserting a new one.
    await loadMessages();
    print('Message inserted.');
  }

  Future<void> loadMessages() async {
    final database = await createDatabase();
    final List<Map<String, dynamic>> result = await database.query('messages');

    setState(() {
      messages = result.map((map) => '${map['sender']}: ${map['message']}').toList();
    });

    print('Messages loaded: $messages');
  }

  void handleReceivedMessage(String receivedMessage) {
    // Handle the received message from another device.
    setState(() {
      messages.add('Other: $receivedMessage');
    });
    broadcastMessage(receivedMessage);
  }

  void handleClientDisconnect(Socket client) {
    clients.remove(client);
    print('Client disconnected');
  }

  void broadcastMessage(String message) {
    clients.forEach((client) {
      client.write(utf8.encode(message));
    });
  }

  void sendMessage(String message) {
    clients.forEach((client) {
      client.write(utf8.encode(message));
    });

    setState(() {
      messages.add('You: $message');
    });
    insertMessage('You', message); // Insert your own messages to the local database
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat Room: ${widget.roomName}'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(messages[index]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onSubmitted: (_) {
                      sendMessage(_messageController.text);
                      _messageController.clear();
                    },
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    sendMessage(_messageController.text);
                    _messageController.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    server?.close();
    clients.forEach((client) {
      client.close();
    });
    super.dispose();
  }
}
