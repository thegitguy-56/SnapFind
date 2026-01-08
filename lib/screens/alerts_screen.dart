import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'item_detail_screen.dart';
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
      appBar: AppBar(title: const Text('Alerts')),
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

          return RefreshIndicator(
            color: Colors.blue,
            onRefresh: () async {
              await FirebaseFirestore.instance
                  .collection('alerts')
                  .where('finderId', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
                  .get();
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final alertDoc = docs[index];
                final alertData = alertDoc.data();
                final alertId = alertDoc.id;
                final itemId = (alertData['itemId'] ?? '').toString();
                final seekerId = (alertData['seekerId'] ?? '').toString();
                final seekerEmail = (alertData['seekerEmail'] ?? 'Unknown')
                    .toString();
                final status = (alertData['status'] ?? '').toString();

                return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance
                      .collection('items')
                      .doc(itemId)
                      .get(),
                  builder: (context, itemSnap) {
                    if (itemSnap.connectionState == ConnectionState.waiting) {
                      return const ListTile(
                        leading: CircularProgressIndicator(),
                        title: Text('Loading…'),
                      );
                    }

                    final docSnap = itemSnap.data;
                    final itemData = docSnap?.data() ?? <String, dynamic>{};
                    final String itemTitle =
                        ((itemData['title'] ?? itemData['objectType']) ?? '')
                            .toString()
                            .trim();
                    final List<dynamic> urlsDynamic =
                        (itemData['imageUrls'] as List<dynamic>?) ?? [];
                    final String? thumbUrl = urlsDynamic.isNotEmpty
                        ? urlsDynamic.first.toString()
                        : null;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Card(
                        elevation: 2,
                        color: Colors.lightBlue.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          leading: Icon(
                            status == 'pending'
                                ? Icons.notifications_active
                                : Icons.notifications_none,
                            color: status == 'pending'
                                ? Colors.orange
                                : Colors.grey,
                          ),
                          title: Text(
                            itemTitle.isNotEmpty
                                ? 'Alert for: $itemTitle'
                                : 'Alert for item: $itemId',
                          ),
                          subtitle: const Text(
                            'From: Anonymous User',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: thumbUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 64,
                                    height: 64,
                                    child: Image.network(
                                      thumbUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey.shade200,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.image_not_supported,
                                        ),
                                      ),
                                      loadingBuilder:
                                          (context, child, progress) {
                                            if (progress == null) return child;
                                            return Container(
                                              color: Colors.grey.shade200,
                                              alignment: Alignment.center,
                                              child: const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () async {
                            // Mark as seen
                            await FirebaseFirestore.instance
                                .collection('alerts')
                                .doc(alertId)
                                .update({'status': 'seen'});

                            final resolvedSnap =
                                docSnap ??
                                await FirebaseFirestore.instance
                                    .collection('items')
                                    .doc(itemId)
                                    .get();

                            if (!resolvedSnap.exists) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Item not found')),
                              );
                              return;
                            }

                            final fullItemData = resolvedSnap.data() ?? {};

                            final chatsRef = FirebaseFirestore.instance
                                .collection('chats');

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
                              // Create new chat with emails persisted
                              final finderEmail = user.email ?? '';
                              final newChatRef = await chatsRef.add({
                                'itemId': itemId,
                                'finderId': user.uid,
                                'finderEmail': finderEmail,
                                'seekerId': seekerId,
                                'seekerEmail': seekerEmail,
                                'createdAt': FieldValue.serverTimestamp(),
                                'lastMessage': '',
                                'lastMessageAt': FieldValue.serverTimestamp(),
                                'lastSenderRole': '',
                                'finderLastReadAt':
                                    FieldValue.serverTimestamp(),
                                'seekerLastReadAt':
                                    FieldValue.serverTimestamp(),
                              });
                              chatId = newChatRef.id;
                            }

                            // ignore: use_build_context_synchronously
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  chatId: chatId,
                                  item: fullItemData,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
