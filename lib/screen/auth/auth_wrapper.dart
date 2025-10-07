import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:money_manager/screen/auth/login_screen.dart';
import 'package:money_manager/screen/home/home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<void> _ensureUserDocumentExists(User user) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await userRef.get();
      
      if (!doc.exists) {
        print('DEBUG: User document missing, creating it now for ${user.uid}');
        
        final now = Timestamp.now();
        final userData = <String, dynamic>{
          'uid': user.uid,
          'email': user.email ?? '',
          'emailLower': (user.email ?? '').toLowerCase(),
          'displayName': user.displayName ?? '',
          'photoURL': user.photoURL,
          'phoneNumber': user.phoneNumber,
          'isEmailVerified': user.emailVerified,
          'providerIds': user.providerData.map((info) => info.providerId).toList(),
          'createdAt': now,
          'updatedAt': now,
          'lastSignInAt': now,
        };
        
        await userRef.set(userData);
        print('DEBUG: User document created successfully');
      } else {
        // Update last sign in time for existing users
        await userRef.update({
          'lastSignInAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });
        print('DEBUG: Updated existing user document sign-in time');
      }
    } catch (e) {
      print('DEBUG: Error ensuring user document exists: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading spinner while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: Colors.teal,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Handle authentication errors
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Authentication Error',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Force rebuild by signing out and back in
                      FirebaseAuth.instance.signOut();
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          );
        }

        // User is authenticated
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          
          // Ensure user document exists in Firestore
          _ensureUserDocumentExists(user);
          
          return const HomeScreen();
        }

        // User is not authenticated
        return const LoginScreen();
      },
    );
  }
}