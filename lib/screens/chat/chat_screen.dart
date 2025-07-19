import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;

  const ChatScreen({super.key, required this.chatId, required this.otherUserName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final DatabaseReference _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://dropbuddy-506d3-default-rtdb.asia-southeast1.firebasedatabase.app',
  ).ref();

  List<Map<String, dynamic>> messages = [];
  final String myUid = FirebaseAuth.instance.currentUser!.uid;
  String myName = '';

  @override
  void initState() {
    super.initState();
    fetchMyName();
    listenToMessages();
  }

  void fetchMyName() async {
    final snapshot = await _db.child('users').child(myUid).get();
    if (snapshot.exists) {
      setState(() {
        myName = (snapshot.value as Map)['name'] ?? '';
      });
    }
  }

  void listenToMessages() {
    _db.child('chats').child(widget.chatId).child('messages').onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;

      final List<Map<String, dynamic>> fetched = data.entries.map((e) {
        final value = Map<String, dynamic>.from(e.value);
        value['key'] = e.key;
        return value;
      }).toList();

      fetched.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

      setState(() {
        messages = fetched;
      });
    });
  }

  void sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final newMsgRef = _db.child('chats').child(widget.chatId).child('messages').push();
    await newMsgRef.set({
      'senderId': myUid,
      'senderName': myName,
      'text': text.trim(),
      'timestamp': DateTime.now().toIso8601String(),
    });

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Chat with ${widget.otherUserName}")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg['senderId'] == myUid;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.lightBlue[100] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(msg['text']),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: "Type a message"),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => sendMessage(_controller.text),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
