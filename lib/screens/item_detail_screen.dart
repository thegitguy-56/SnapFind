import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  final Map<String, dynamic> item;

  const ItemDetailScreen({super.key, required this.item});

  Future<void> _onAlertPressed(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to alert the finder")),
      );
      return;
    }

    final String seekerId = user.uid;
    final String? finderId = item['userId']?.toString();
    final String? itemId =
        item['id']?.toString() ?? item['docId']?.toString();

    if (finderId == null || itemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing item information")),
      );
      return;
    }

    // If you are the finder, no alert needed
    if (finderId == seekerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You posted this item")),
      );
      return;
    }

    final alertsRef = FirebaseFirestore.instance.collection('alerts');

    try {
      // Check if an alert already exists for this item + seeker
      final existing = await alertsRef
          .where('itemId', isEqualTo: itemId)
          .where('seekerId', isEqualTo: seekerId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You already alerted the finder")),
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
        const SnackBar(content: Text("Please log in to chat with the finder")),
      );
      return;
    }

    final String seekerId = user.uid;
    final String? finderId = item['userId']?.toString();
    final String? itemId =
        item['id']?.toString() ?? item['docId']?.toString();

    if (finderId == null || itemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing item information")),
      );
      return;
    }

    final chatsRef = FirebaseFirestore.instance.collection('chats');
    String chatId;

    try {
      // 1) Check if a chat already exists between this seeker and finder for this item
      final existing = await chatsRef
          .where('itemId', isEqualTo: itemId)
          .where('finderId', isEqualTo: finderId)
          .where('seekerId', isEqualTo: seekerId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        chatId = existing.docs.first.id;
      } else {
        // 2) Create a new chat document
        final newChatRef = await chatsRef.add({
          'itemId': itemId,
          'finderId': finderId,
          'seekerId': seekerId,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageAt': FieldValue.serverTimestamp(),
        });
        chatId = newChatRef.id;
      }

      // 3) Navigate to ChatScreen
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              item: item,
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
    final List<dynamic> urlsDynamic = item['imageUrls'] ?? <dynamic>[];
    final List<String> urls = urlsDynamic.cast<String>();
    final note = (item['note'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item details'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                if (urls.isNotEmpty)
                  SizedBox(
                    height: 260,
                    width: double.infinity,
                    child: PageView.builder(
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
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main heading bigger
                        Text(
                          item['objectType'] ?? '',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Bold labels for fields
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
                                text: (item['color'] ?? '').toString(),
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
                                text: (item['brand'] ?? '').toString(),
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
                                text: (item['location'] ?? '').toString(),
                              ),
                            ],
                          ),
                        ),
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
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: note),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'Posted by: ${item['userEmail'] ?? ''}',
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Buttons section – visually higher
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _onAlertPressed(context),
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
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _onChatPressed(context),
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
