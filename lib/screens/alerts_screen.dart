import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// import 'item_detail_screen.dart';
import 'chat_screen.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to see alerts')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('alerts')
            .where('finderId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No alerts yet',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final alertDoc = docs[index];
              final alertData = alertDoc.data();
              final alertId = alertDoc.id;
              final itemId = (alertData['itemId'] ?? '').toString();
              final seekerId = (alertData['seekerId'] ?? '').toString();
              final status = (alertData['status'] ?? '').toString();

              return ListTile(
                leading: Icon(
                  status == 'pending'
                      ? Icons.notifications_active
                      : Icons.notifications_none,
                  color: status == 'pending' ? Colors.orange : Colors.grey,
                ),
                title: Text('Alert for item: $itemId'),
                subtitle: Text('From user: $seekerId'),
                onTap: () async {
                  // Mark as seen
                  await FirebaseFirestore.instance
                      .collection('alerts')
                      .doc(alertId)
                      .update({'status': 'seen'});

                  // Fetch item data
                  final itemSnap = await FirebaseFirestore.instance
                      .collection('items')
                      .doc(itemId)
                      .get();

                  if (!itemSnap.exists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Item not found'),
                      ),
                    );
                    return;
                  }

                  final itemData = itemSnap.data() ?? {};

                  // Option 1: open item details
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(
                  //     builder: (_) => ItemDetailScreen(item: itemData),
                  //   ),
                  // );

                  // Option 2: directly open chat about this item
                  final chatsRef =
                      FirebaseFirestore.instance.collection('chats');

                  final existing = await chatsRef
                      .where('itemId', isEqualTo: itemId)
                      .where('finderId', isEqualTo: user.uid)
                      .where('seekerId', isEqualTo: seekerId)
                      .limit(1)
                      .get();

                  String chatId;
                  if (existing.docs.isNotEmpty) {
                    chatId = existing.docs.first.id;
                  } else {
                    final newChatRef = await chatsRef.add({
                      'itemId': itemId,
                      'finderId': user.uid,
                      'seekerId': seekerId,
                      'createdAt': FieldValue.serverTimestamp(),
                      'lastMessage': '',
                      'lastMessageAt': FieldValue.serverTimestamp(),
                    });
                    chatId = newChatRef.id;
                  }

                  // ignore: use_build_context_synchronously
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatId: chatId,
                        item: itemData,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
