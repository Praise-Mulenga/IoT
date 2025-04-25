import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'sensors/sensor_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase with your credentials
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCnDaQNTEvpAcdSKYj00e9qUMNrh_5Rj-k",
        authDomain: "enviromental-monitor-ad43d.firebaseapp.com",
        //databaseURL: "https://homehunt-53202-default-rtdb.firebaseio.com", // Note: This doesn't match project ID
        projectId: "enviromental-monitor-ad43d",
        storageBucket: "enviromental-monitor-ad43d.firebasestorage.app",
        messagingSenderId: "457793809758",
        appId: "1:457793809758:web:56d81c47a1a04833b973cf",
        measurementId: "G-M17G5G5954"
      ),
    );

    /* Sign in anonymously
    await FirebaseAuth.instance.signInAnonymously();
    print('Anonymous user signed in: ${FirebaseAuth.instance.currentUser?.uid}'); */
    
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  runApp(const SensorApp());
}

class SensorApp extends StatelessWidget {
  const SensorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Environmental Monitor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SensorScreen(),
    );
  }
}