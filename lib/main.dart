import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'pages/login_screen.dart';
import 'pages/home_screen.dart';
import 'pages/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Watt Wizard',
      theme: ThemeData(
        primaryColor: const Color(0xFF1E425E),
        scaffoldBackgroundColor: const Color(0xFFEFF5F5),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black87),
        ),
      ),
      initialRoute: '/splash', // Set initial route
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
