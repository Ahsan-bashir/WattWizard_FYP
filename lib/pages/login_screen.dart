import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'signup_screen.dart';
import 'home_screen.dart';
import 'forgot_password.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Initialize Firestore
  bool _isLoading = false;

  Future<void> _login(BuildContext context) async {
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;

      if (user != null) {
        DocumentReference userDocRef = _firestore.collection('users').doc(user.uid);

        // Always attempt to set/merge basic user profile and settings
        // This handles both new users (document won't exist, will be created)
        // and existing users (document will be merged)
        await userDocRef.set({
          'profile': {
            'email': user.email,
            'displayName': user.displayName ?? user.email?.split('@')[0],
          },
          'settings': {
            'unitLimit': 200, // Default unit limit
          },
        }, SetOptions(merge: true)); // Use merge to avoid overwriting existing fields

        debugPrint('User document (profile/settings) ensured for ${user.uid}');

        // Now, check and populate the devices subcollection
        CollectionReference devicesCollectionRef = userDocRef.collection('devices');
        QuerySnapshot devicesSnapshot = await devicesCollectionRef.get();

        if (devicesSnapshot.docs.isEmpty) {
          debugPrint('Devices collection is empty for ${user.uid}. Populating...');
          await devicesCollectionRef.doc('fan_01').set({
            'name': 'Fan',
            'status': false,
            'power_baseline_watts': 10,
          });
          await devicesCollectionRef.doc('light_01').set({
            'name': 'Green Light',
            'status': false,
            'power_baseline_watts': 0.3,
          });
          await devicesCollectionRef.doc('light_02').set({
            'name': 'Red Light',
            'status': false,
            'power_baseline_watts': 0.3,
          });
          await devicesCollectionRef.doc('socket_01').set({
            'name': 'Socket',
            'status': false,
            'power_baseline_watts': 100, // Example baseline
          });
          debugPrint('Default devices populated for ${user.uid}');
        } else {
          debugPrint('Devices collection already exists and is not empty for ${user.uid}');
        }

        // Navigate to home screen if login is successful
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Login failed. Please try again.";
      if (e.code == 'user-not-found') {
        errorMessage = "No user found for this email.";
      } else if (e.code == 'wrong-password') {
        errorMessage = "Incorrect password. Please try again.";
      } else if (e.code == 'invalid-email') {
        errorMessage = "The email address is not valid.";
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Login",style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E425E),
        centerTitle: true,
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(), // dismiss keyboard when tapping outside
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  Image.asset(
                    'assets/images/logo_small_bg_removed.png',
                    width: 150,
                    height: 150,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "WattWizard: AI-Powered Energy Consumption Monitoring",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E425E),
                    ),
                  ),
                  const SizedBox(height: 30),

                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: _isLoading ? null : () => _login(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E425E),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Login", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                  const SizedBox(height: 10),

                  TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen()));
                    },
                    child: const Text("Don't have an account? Sign up", style: TextStyle(color: Color(0xFF1E425E))),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => ForgotPasswordPage()));
                    },
                    child: const Text("Forgot Password? Click Here", style: TextStyle(color: Color(0xFF1E425E))),
                  ),
                  const SizedBox(height: 30), // extra space at bottom
                ],
              ),
            ),
          ),
        ),
      ),

    );
  }
}
