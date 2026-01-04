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
    required File image,
    required Map<String, dynamic> tags,
    required String location,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // 1) Upload image
    final id = const Uuid().v4();
    final ref = _storage.ref().child('items/$id.jpg');
    await ref.putFile(image);
    final url = await ref.getDownloadURL();

    // 2) Save document
    await _firestore.collection('items').doc(id).set({
      'id': id,
      'userId': user.uid,
      'userEmail': user.email,
      'objectType': tags['object_type'] ?? '',
      'color': tags['color'] ?? '',
      'brand': tags['brand'] ?? '',
      'imageUrl': url,
      'location': location,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'found',
      'matched': false,
    });
  }

  static Stream<List<Map<String, dynamic>>> getItemsStream() {
    return _firestore
        .collection('items')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {...d.data(), 'docId': d.id})
            .toList());
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
