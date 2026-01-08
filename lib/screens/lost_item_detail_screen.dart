// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'chat_screen.dart';
import '../utils/date_utils.dart'; // formatTimestamp(...)

class LostItemDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const LostItemDetailScreen({super.key, required this.item});

  @override
  State<LostItemDetailScreen> createState() => _LostItemDetailScreenState();
}

class _LostItemDetailScreenState extends State<LostItemDetailScreen> {
  late Map<String, dynamic> _item;

  @override
  void initState() {
    super.initState();
    _item = Map<String, dynamic>.from(widget.item);
  }

  Future<String> _ensureChatAndSendVerification({
    required String finderId,
    required String finderEmail,
    required String seekerId,
    required String seekerEmail,
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
        'finderEmail': finderEmail,
        'seekerId': seekerId,
        'seekerEmail': seekerEmail,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderRole': '',
        'finderLastReadAt': FieldValue.serverTimestamp(),
        'seekerLastReadAt': FieldValue.serverTimestamp(),
        'hasVerification': false,
        'status': 'pending',
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
        const SnackBar(content: Text('Please log in to alert the owner')),
      );
      return;
    }

    final String seekerId = user.uid;
    final String seekerEmail = user.email ?? '';
    final String? finderId = _item['userId']?.toString();
    final String finderEmail = (_item['reportedBy'] ?? _item['userEmail'] ?? '')
        .toString();
    final String? itemId =
        _item['id']?.toString() ?? _item['docId']?.toString();

    if (finderId == null || itemId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Missing item information")));
      return;
    }

    if (finderId == seekerId) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("You posted this item")));
      return;
    }

    final location = (_item['lastKnownLocation'] ?? '').toString();
    final verificationText = location.isNotEmpty
        ? 'I found this near $location'
        : 'I found this item';

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
          'finderEmail': finderEmail,
          'seekerId': seekerId,
          'seekerEmail': seekerEmail,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
      }

      final chatId = await _ensureChatAndSendVerification(
        finderId: finderId,
        finderEmail: finderEmail,
        seekerId: seekerId,
        seekerEmail: seekerEmail,
        itemId: itemId,
        verificationText: verificationText,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Details sent to owner. Wait for approval to chat.'),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: chatId, item: _item),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send details: $e')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please log in to chat')));
      return;
    }

    final String seekerId = user.uid;
    final String seekerEmail = user.email ?? '';
    final String? finderId = _item['userId']?.toString();
    final String finderEmail = (_item['reportedBy'] ?? _item['userEmail'] ?? '')
        .toString();
    final String? itemId =
        _item['id']?.toString() ?? _item['docId']?.toString();

    if (finderId == null || itemId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Missing item information")));
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
          'finderEmail': finderEmail,
          'seekerId': seekerId,
          'seekerEmail': seekerEmail,
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
            builder: (_) => ChatScreen(chatId: chatId, item: _item),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to open chat: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lost items: single imageUrl, notes, lastKnownLocation, itemName, category.
    final String? imageUrl = _item['imageUrl'] as String?;
    final String title = (_item['itemName'] ?? 'Item').toString();
    final String category = (_item['category'] ?? '').toString();
    final String location = (_item['lastKnownLocation'] ?? '').toString();
    final String note = (_item['notes'] ?? '').toString();
    final String status = (_item['status'] as String?) ?? 'lost';
    final bool isReturned = status == 'returned';
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Lost item details')),
      body: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty)
                  SizedBox(
                    height: 260,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, _) => Container(
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: const SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, _, __) => Container(
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.grey.shade500,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (isReturned)
                          Container(
                            height: 260,
                            width: double.infinity,
                            margin: const EdgeInsets.all(8),
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
                          title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (category.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            category,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Last known location: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: location),
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
                                  text: 'Notes: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: note),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Lost on: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: formatTimestamp(_item['lostDate']),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reported on: ${formatTimestamp(_item['createdAt'])}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.blueGrey,
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
            padding: EdgeInsets.fromLTRB(12, 16, 12, 24 + bottomInset),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isReturned
                          ? Colors.grey
                          : Colors.orangeAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isReturned
                        ? null
                        : () => _showVerificationDialog(context),
                    child: const Text(
                      'I found this',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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
                            : "Chat with owner",
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: disabled
                                ? Colors.grey
                                : Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: disabled
                              ? null
                              : () => _onChatPressed(context),
                          child: const Text(
                            'Chat with owner',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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
