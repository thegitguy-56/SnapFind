import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'item_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('items')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'returned')
        .orderBy('timestamp', descending: true)
        .snapshots(); // [web:613][web:660]

    return Scaffold(
      appBar: AppBar(
        title: const Text('Returned items'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No returned items yet'));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              return ListTile(
                title: Text(data['objectType'] ?? ''),
                subtitle: Text('Location: ${data['location'] ?? ''}'),
                onTap: () {
                  // pass same map shape as Feed uses
                  final item = {
                    ...data,
                    'docId': doc.id,
                  };
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ItemDetailScreen(item: item),
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
