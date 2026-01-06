import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> saveItem({
    required List<File> images,
    required Map<String, dynamic> tags,
    required String location,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // 1) Upload all images and collect URLs
    final id = const Uuid().v4();
    final List<String> imageUrls = [];

    for (int i = 0; i < images.length; i++) {
      final file = images[i];
      final ref = _storage.ref().child('items/${id}_$i.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      imageUrls.add(url);
    }

    // 2) Save document with list of image URLs + note
    await _firestore.collection('items').doc(id).set({
      'id': id,
      'userId': user.uid, // finder / uploader
      'userEmail': user.email,
      'objectType': tags['object_type'] ?? '',
      'color': tags['color'] ?? '',
      'brand': tags['brand'] ?? '',
      'note': tags['note'] ?? '',
      'imageUrls': imageUrls,
      'location': location,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'found', // not returned yet
      'matched': false,
    });
  }

  // ✅ FIXED getItemsStream
  static Stream<List<Map<String, dynamic>>> getItemsStream() {
    return _firestore
        .collection('items')
        // 1. REMOVE the .orderBy() here. It hides data!
        // .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          final docs = snap.docs.map((d) {
            final data = d.data();

            // Normalize status
            final normalizedStatus = (data['status']?.toString() ?? '')
                .trim()
                .toLowerCase();

            // 2. Handle both naming conventions safely
            final timeField = data['createdAt'] ?? data['timestamp'];

            return {
              ...data,
              'docId': d.id,
              'status': normalizedStatus,
              'createdAt': timeField, // Unify them into one key for the UI
            };
          }).toList();

          // 3. Sort here in Dart (Safe for mixed data)
          docs.sort((a, b) {
            final tA = a['createdAt']; // Could be Timestamp or null
            final tB = b['createdAt'];

            if (tA == null) return 1; // Nulls go to bottom
            if (tB == null) return -1;

            // Firestore Timestamps have a compareTo method
            return tB.compareTo(tA); // Descending order
          });

          return docs;
        });
  }

  static Future<List<Map<String, dynamic>>> searchItems(String query) async {
    final q = query.toLowerCase();
    final snap = await _firestore.collection('items').get();
    return snap.docs
        .where((d) {
          final data = d.data();
          final t = (data['objectType'] ?? '').toString().toLowerCase();
          final c = (data['color'] ?? '').toString().toLowerCase();
          final b = (data['brand'] ?? '').toString().toLowerCase();
          return t.contains(q) || c.contains(q) || b.contains(q);
        })
        .map((d) => {...d.data(), 'docId': d.id})
        .toList();
  }
}
