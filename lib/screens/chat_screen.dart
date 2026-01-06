import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final Map<String, dynamic> item;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.item,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _auth = FirebaseAuth.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messagesSub;
  String? _myRole;
  bool _markedInitialRead = false;

  @override
  void dispose() {
    _messagesSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final String currentUid = user.uid;
    final String finderId = widget.item['userId']?.toString() ?? '';

    _myRole ??= currentUid == finderId ? 'finder' : 'seeker';

    // Determine role based on ids
    final String senderRole =
        currentUid == finderId ? 'finder' : 'seeker';

    final chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId);

    final messagesRef = chatRef.collection('messages');

    final now = FieldValue.serverTimestamp();

    await messagesRef.add({
      'senderRole': senderRole,
      'text': text,
      'createdAt': now,
    });

    await chatRef.update({
      'lastMessage': text,
      'lastMessageAt': now,
      'lastSenderRole': senderRole,
    });

    // Slight delay then scroll to bottom
    await Future.delayed(const Duration(milliseconds: 200));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _markChatRead() async {
    final role = _myRole;
    if (role == null) return;

    final fieldName =
        role == 'finder' ? 'finderLastReadAt' : 'seekerLastReadAt';

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({fieldName: FieldValue.serverTimestamp()});
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final String currentUid = user?.uid ?? '';
    final String finderId = widget.item['userId']?.toString() ?? '';

    _myRole ??= currentUid == finderId ? 'finder' : 'seeker';

    // Keep the chat marked as read while the screen is visible.
    _messagesSub ??= FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen((_) => _markChatRead());

    if (!_markedInitialRead) {
      _markedInitialRead = true;
      _markChatRead();
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.item['objectType'] ?? 'Chat about this item'),
            const Text(
              'Anonymous chat',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Say hi to start the conversation',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final senderRole = (data['senderRole'] ?? '').toString();
                    final text = (data['text'] ?? '').toString();

                    // isCurrentUser: true if this message is from me
                    final bool isCurrentUser =
                        (senderRole == 'finder' && currentUid == finderId) ||
                        (senderRole == 'seeker' && currentUid != finderId);

                    final Alignment alignment = isCurrentUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft;

                    final Color bubbleColor = isCurrentUser
                        ? Colors.teal
                        : Colors.grey.shade300;

                    final Color textColor =
                        isCurrentUser ? Colors.white : Colors.black87;

                    return Align(
                      alignment: alignment,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          text,
                          style: TextStyle(color: textColor, fontSize: 15),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Input field (visually higher)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  offset: const Offset(0, -1),
                  blurRadius: 4,
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 22),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Type a message…',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.teal),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
