import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> saveFcmToken() async {
  // 1. User must be logged in (Firebase Auth)
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('No user logged in');
    return;
  }

  // 2. Get FCM token for this device
  final token = await FirebaseMessaging.instance.getToken();
  if (token == null) {
    print('No FCM token');
    return;
  }

  // 3. Save token to Firestore: users/{uid}/tokens/{token}
  final docRef = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('tokens')
      .doc(token);

  await docRef.set({
    'token': token,
    'createdAt': FieldValue.serverTimestamp(),
    'platform': 'flutter',
  }, SetOptions(merge: true));

  print('Saved FCM token for user ${user.uid}');
}
