import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> _setupPush() async {
  final messaging = FirebaseMessaging.instance;

  // Request notification permissions (Android 13+ and iOS)
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Get FCM token
  final token = await messaging.getToken();
  final user = FirebaseAuth.instance.currentUser;

  if (token != null && user != null) {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tokens')
        .doc(token)
        .set({
      'token': token,
      'createdAt': FieldValue.serverTimestamp(),
      'platform': 'flutter',
    }, SetOptions(merge: true));
  }

  // Optional: handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    // You can show a Snackbar or dialog here if you want
    // debugPrint('Foreground message: ${message.notification?.title}');
  });
}

Future<void> _setupInteractedMessages() async {
  // App opened from terminated state by tapping notification
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    _handleMessageNavigation(initialMessage.data);
  }

  // App in background, resumed from notification
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleMessageNavigation(message.data);
  });
}

void _handleMessageNavigation(Map<String, dynamic> data) {
  // Later you can navigate based on data['type'], data['itemId'], data['chatId']
  // For now, this is left empty.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await _setupInteractedMessages();

  // Listen for token refresh and keep Firestore updated
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tokens')
        .doc(newToken)
        .set({
      'token': newToken,
      'createdAt': FieldValue.serverTimestamp(),
      'platform': 'flutter',
    }, SetOptions(merge: true));
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnapFind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            // User is logged in → set up push & save token once per auth change
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _setupPush();
            });
            return const HomeScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}
