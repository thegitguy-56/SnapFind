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
      // Keep the pull-to-refresh gesture responsive even if we lack an id.
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

  Future<void> _onAlertPressed(BuildContext context) async {
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

    final alertsRef = FirebaseFirestore.instance.collection('alerts');

    try {
      final existing = await alertsRef
          .where('itemId', isEqualTo: itemId)
          .where('seekerId', isEqualTo: seekerId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already alerted the finder')),
        );
        return;
      }

      await alertsRef.add({
        'itemId': itemId,
        'finderId': finderId,
        'seekerId': seekerId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Alert sent to finder")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send alert: $e")),
      );
    }
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

          // Buttons section – disabled when returned
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
                        isReturned ? null : () => _onAlertPressed(context),
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
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isReturned ? Colors.grey : Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed:
                        isReturned ? null : () => _onChatPressed(context),
                    child: const Text(
                      "Chat with finder",
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
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