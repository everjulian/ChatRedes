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
      debugShowCheckedModeBanner: false,
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
        title: const Text('🚪 Selecciona o Crea una Sala'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // 📝 Campo de texto para ingresar el nombre de la sala
            TextField(
              controller: _roomController,
              decoration: const InputDecoration(
                labelText: '🏠 Ingresa el Nombre de la Sala',
              ),
            ),
            const SizedBox(height: 16.0),
            // 🚀 Botones para unirse a una sala o crear una nueva
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    final roomName = _roomController.text;
                    if (roomName.isNotEmpty) {
                      // 🌐 Navegar a la pantalla de chat al presionar el botón
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(roomName: roomName),
                        ),
                      );
                    }
                  },
                  child: const Text('🚀 Unirse a la Sala'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final roomName = _roomController.text;
                    if (roomName.isNotEmpty) {
                      // 🌐 Navegar a la pantalla de chat al presionar el botón
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(roomName: roomName),
                        ),
                      );
                    }
                  },
                  child: const Text('➕ Crear Sala'),
                ),
              ],
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
    // 🚀 Inicializar la conexión de red y la base de datos al iniciar la pantalla de chat
    initNetwork();
    initDatabase();
  }

  Future<void> initDatabase() async {
    // 📦 Inicializar la base de datos local
    print('🗃️ Base de datos inicializada.');

    // 🔄 Cargar mensajes desde la base de datos cuando la aplicación inicia.
    await loadMessages();
  }

  Future<Database> createDatabase() async {
    // 📁 Obtener la carpeta de la base de datos
    final databaseFolder = await getDatabasesPath();
    return openDatabase(
      // 🚀 Abrir la base de datos con el nombre de la sala
      join(databaseFolder, '${widget.roomName}_chat_database.db'),
      onCreate: (db, version) {
        // 📝 Crear la tabla de mensajes si la base de datos es creada por primera vez
        db.execute(
          'CREATE TABLE messages (id INTEGER PRIMARY KEY, sender TEXT, message TEXT, timestamp INTEGER)',
        );
      },
      version: 1,
    );
  }

  Future<void> initNetwork() async {
    try {
      // 🌐 Crear un servidor de sockets
      server = await ServerSocket.bind('0.0.0.0', 12345);
      // 🎧 Escuchar a los clientes conectados
      server?.listen((Socket clientSocket) {
        setState(() {
          // 🚀 Agregar clientes a la lista cuando se conectan
          clients.add(clientSocket);
        });
        clientSocket.listen(
          (List<int> data) {
            // 📡 Manejar mensajes recibidos de los clientes
            final receivedMessage = utf8.decode(data);
            handleReceivedMessage(receivedMessage);
          },
          onDone: () {
            // 🚀 Manejar la desconexión del cliente
            print('🚫 Cliente desconectado');
            handleClientDisconnect(clientSocket);
          },
        );
      });
    } catch (e) {
      print('❌ Error al crear el servidor: $e');
    }
  }

  Future<void> insertMessage(String sender, String message) async {
    // 📦 Obtener la base de datos local
    final database = await createDatabase();
    // 📥 Insertar un mensaje en la base de datos
    await database.insert(
      'messages',
      {
        'sender': sender,
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 🔄 Recargar mensajes después de insertar uno nuevo
    await loadMessages();
    print('✉️ Mensaje insertado.');
  }

  Future<void> loadMessages() async {
    // 📦 Obtener la base de datos local
    final database = await createDatabase();
    // 📋 Consultar mensajes desde la base de datos
    final List<Map<String, dynamic>> result = await database.query('messages');

    setState(() {
      // 🚀 Actualizar la lista de mensajes
      messages = result.map((map) => '${map['sender']}: ${map['message']}').toList();
    });

    print('✉️ Mensajes cargados: $messages');
  }

  void handleReceivedMessage(String receivedMessage) {
    // 📡 Manejar el mensaje recibido de otro dispositivo
    setState(() {
      messages.add('👤 Otro: $receivedMessage');
    });
    // 📡 Transmitir el mensaje a todos los clientes conectados
    broadcastMessage(receivedMessage);
  }

  void handleClientDisconnect(Socket client) {
    // 🚀 Manejar la desconexión del cliente
    clients.remove(client);
    print('🚫 Cliente desconectado');
  }

  void broadcastMessage(String message) {
    // 📡 Transmitir el mensaje a todos los clientes conectados
    for (var client in clients) {
      client.write(utf8.encode(message));
    }
  }

  void sendMessage(String message) {
    // 📡 Transmitir el mensaje a todos los clientes conectados
    for (var client in clients) {
      client.write(utf8.encode(message));
    }

    setState(() {
      // 🚀 Agregar el mensaje propio a la lista visual
      messages.add('👤 Tú: $message');
    });
    // 📦 Insertar mensajes propios en la base de datos local
    insertMessage('Tú', message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 🚀 Mostrar el nombre de la sala en la barra de aplicación
        title: Text('🗨️ Sala de Chat: ${widget.roomName}'),
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
                      // 📡 Enviar mensaje al presionar "Enter"
                      sendMessage(_messageController.text);
                      _messageController.clear();
                    },
                    decoration: const InputDecoration(
                      hintText: '📝 Escribe un mensaje...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    // 📡 Enviar mensaje al presionar el botón de enviar
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
    // 🚀 Cerrar el servidor y los clientes al cerrar la pantalla de chat
    server?.close();
    for (var client in clients) {
      client.close();
    }
    super.dispose();
  }
}
