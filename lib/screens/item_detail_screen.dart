import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late Map<String, dynamic> _item;

  @override
  void initState() {
    super.initState();
    _item = Map<String, dynamic>.from(widget.item);
  }

  Future<void> _refreshItem() async {
    final String? docId = _item['docId']?.toString() ?? _item['id']?.toString();
    if (docId == null) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return;
    }

    try {
      final snap =
          await FirebaseFirestore.instance.collection('items').doc(docId).get();

      if (!snap.exists || snap.data() == null) return;

      setState(() {
        _item = {...snap.data()!, 'docId': snap.id};
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refresh failed: $e')),
      );
    }
  }

  Future<String> _ensureChatAndSendVerification({
    required String finderId,
    required String seekerId,
    required String itemId,
    required String verificationText,
  }) async {
    final chatsRef = FirebaseFirestore.instance.collection('chats');

    final existing = await chatsRef
        .where('itemId', isEqualTo: itemId)
        .where('finderId', isEqualTo: finderId)
        .where('seekerId', isEqualTo: seekerId)
        .limit(1)
        .get();

    DocumentReference<Map<String, dynamic>> chatRef;

    if (existing.docs.isNotEmpty) {
      chatRef = existing.docs.first.reference;
    } else {
      chatRef = await chatsRef.add({
        'itemId': itemId,
        'finderId': finderId,
        'seekerId': seekerId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderRole': '',
        'finderLastReadAt': FieldValue.serverTimestamp(),
        'seekerLastReadAt': FieldValue.serverTimestamp(),
        'hasVerification': false,
        'status': 'pending', // chat approval status
      });
    }

    final messagesRef = chatRef.collection('messages');
    final now = FieldValue.serverTimestamp();

    await messagesRef.add({
      'senderRole': 'seeker',
      'text': verificationText,
      'createdAt': now,
      'type': 'verification',
    });

    await chatRef.update({
      'lastMessage': verificationText,
      'lastMessageAt': now,
      'lastSenderRole': 'seeker',
      'hasVerification': true,
      'status': 'pending',
    });

    return chatRef.id;
  }

  Future<void> _showVerificationDialog(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to alert the finder')),
      );
      return;
    }

    final String seekerId = user.uid;
    final String? finderId = _item['userId']?.toString();
    final String? itemId =
        _item['id']?.toString() ?? _item['docId']?.toString();

    if (finderId == null || itemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing item information")),
      );
      return;
    }

    if (finderId == seekerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You posted this item")),
      );
      return;
    }

    final whereController = TextEditingController();
    final whenController = TextEditingController();
    final marksController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Help verify that it is yours'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: whereController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Where exactly did you lose it?',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: whenController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Approximate time of loss?',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: marksController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText:
                        'Any unique marks or details? (Dents, scratches, etc.)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (whereController.text.trim().isEmpty ||
                    whenController.text.trim().isEmpty ||
                    marksController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all three answers.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    if (result != true) {
      return;
    }

    final verificationText = '''
Where exactly did you lose it?
${whereController.text.trim()}

Approximate time of loss?
${whenController.text.trim()}

Unique marks or details:
${marksController.text.trim()}
''';

    try {
      final alertsRef = FirebaseFirestore.instance.collection('alerts');
      final existingAlert = await alertsRef
          .where('itemId', isEqualTo: itemId)
          .where('seekerId', isEqualTo: seekerId)
          .limit(1)
          .get();

      if (existingAlert.docs.isEmpty) {
        await alertsRef.add({
          'itemId': itemId,
          'finderId': finderId,
          'seekerId': seekerId,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
      }

      final chatId = await _ensureChatAndSendVerification(
        finderId: finderId,
        seekerId: seekerId,
        itemId: itemId,
        verificationText: verificationText,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Details sent to finder. Wait for approval to chat.'),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            item: _item,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send details: $e')),
      );
    }
  }

  Future<bool> _hasVerificationForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final String seekerId = user.uid;
    final String? finderId = _item['userId']?.toString();
    final String? itemId =
        _item['id']?.toString() ?? _item['docId']?.toString();

    if (finderId == null || itemId == null) return false;

    final chatsRef = FirebaseFirestore.instance.collection('chats');

    final existing = await chatsRef
        .where('itemId', isEqualTo: itemId)
        .where('finderId', isEqualTo: finderId)
        .where('seekerId', isEqualTo: seekerId)
        .limit(1)
        .get();

    if (existing.docs.isEmpty) return false;

    final data = existing.docs.first.data();
    return (data['hasVerification'] ?? false) == true;
  }

  Future<void> _onChatPressed(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to chat with the finder')),
      );
      return;
    }

    final String seekerId = user.uid;
    final String? finderId = _item['userId']?.toString();
    final String? itemId =
        _item['id']?.toString() ?? _item['docId']?.toString();

    if (finderId == null || itemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing item information")),
      );
      return;
    }

    final chatsRef = FirebaseFirestore.instance.collection('chats');
    String chatId;

    try {
      final existing = await chatsRef
          .where('itemId', isEqualTo: itemId)
          .where('finderId', isEqualTo: finderId)
          .where('seekerId', isEqualTo: seekerId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        chatId = existing.docs.first.id;
      } else {
        final newChatRef = await chatsRef.add({
          'itemId': itemId,
          'finderId': finderId,
          'seekerId': seekerId,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSenderRole': '',
          'finderLastReadAt': FieldValue.serverTimestamp(),
          'seekerLastReadAt': FieldValue.serverTimestamp(),
          'hasVerification': false,
          'status': 'pending',
        });
        chatId = newChatRef.id;
      }

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              item: _item,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to open chat: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> urlsDynamic = _item['imageUrls'] ?? <dynamic>[];
    final List<String> urls = urlsDynamic.cast<String>();
    final note = (_item['note'] ?? '').toString();
    final String status = (_item['status'] as String?) ?? 'found';

    final bool isReturned = status == 'returned';

    return Scaffold(
      appBar: AppBar(title: const Text('Item details')),
      body: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                if (urls.isNotEmpty)
                  SizedBox(
                    height: 260,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        PageView.builder(
                          itemCount: urls.length,
                          itemBuilder: (context, index) {
                            final url = urls[index];
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                        if (isReturned)
                          Container(
                            height: 260,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'ITEM RETURNED',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _item['objectType'] ?? '',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Color: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: (_item['color'] ?? '').toString(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Brand: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: (_item['brand'] ?? '').toString(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Location: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: (_item['location'] ?? '').toString(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (note.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Note: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: note),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'Posted by: ${_item['userEmail'] ?? ''}',
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (isReturned)
                          const Text(
                            'This item has been returned to its owner.',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isReturned ? Colors.grey : Colors.orangeAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed:
                        isReturned ? null : () => _showVerificationDialog(context),
                    child: const Text(
                      "I'm looking for this",
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FutureBuilder<bool>(
                    future: _hasVerificationForCurrentUser(),
                    builder: (context, snapshot) {
                      final hasVerification = snapshot.data ?? false;
                      final bool disabled = isReturned || !hasVerification;

                      return Tooltip(
                        message: disabled
                            ? "Answer verification questions first"
                            : "Chat with finder",
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                disabled ? Colors.grey : Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed:
                              disabled ? null : () => _onChatPressed(context),
                          child: const Text(
                            "Chat with finder",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
