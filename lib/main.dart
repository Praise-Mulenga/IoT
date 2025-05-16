import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'sensors/sensor_screen.dart'; // This already contains the navigation

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCnDaQNTEvpAcdSKYj00e9qUMNrh_5Rj-k",
        authDomain: "enviromental-monitor-ad43d.firebaseapp.com",
        databaseURL: "https://enviromental-monitor-ad43d-default-rtdb.firebaseio.com",
        projectId: "enviromental-monitor-ad43d",
        storageBucket: "enviromental-monitor-ad43d.appspot.com",
        messagingSenderId: "457793809758",
        appId: "1:457793809758:web:56d81c47a1a04833b973cf",
        measurementId: "G-M17G5G5954"
      ),
    );
    print('Firebase initialized successfully');
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
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const SensorScreen(), // This is your existing screen with navigation
    );
  }
}