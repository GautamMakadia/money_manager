import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    
    try {
      if (_isLogin) {
        await _signIn();
      } else {
        await _signUp();
      }
    } on FirebaseAuthException catch (e) {
      _showErrorMessage(_getAuthErrorMessage(e));
    } catch (e) {
      _showErrorMessage('An unexpected error occurred: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _signIn() async {
    print('DEBUG: Starting sign in process');
    
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    print('DEBUG: Sign in successful for user: ${credential.user?.uid}');
    
    // Update user document on sign in
    await _createOrUpdateUserDocument(credential.user);
  }

  Future<void> _signUp() async {
    final displayName = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    print('DEBUG: Starting sign up process for email: $email');

    // Create Firebase Auth account
    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    print('DEBUG: Firebase Auth account created: ${credential.user?.uid}');

    // Update the user's display name in Firebase Auth
    if (credential.user != null) {
      await credential.user!.updateDisplayName(displayName);
      await credential.user!.reload();
      print('DEBUG: Display name updated in Firebase Auth');
    }

    // Create user document in Firestore
    await _createOrUpdateUserDocument(credential.user, displayName: displayName);
  }

  Future<void> _createOrUpdateUserDocument(User? user, {String? displayName}) async {
    if (user == null) {
      print('DEBUG: User is null, cannot create document');
      return;
    }

    print('DEBUG: Creating/updating user document for ${user.uid}');
    print('DEBUG: Email: ${user.email}');
    print('DEBUG: Display Name: ${displayName ?? user.displayName}');

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(user.uid);

    try {
      // Check if document already exists
      final existingDoc = await userRef.get();
      final now = Timestamp.now();
      
      final userData = <String, dynamic>{
        'uid': user.uid,
        'email': user.email ?? '',
        'emailLower': (user.email ?? '').toLowerCase(),
        'displayName': displayName ?? user.displayName ?? '',
        'photoURL': user.photoURL,
        'phoneNumber': user.phoneNumber,
        'isEmailVerified': user.emailVerified,
        'providerIds': user.providerData.map((info) => info.providerId).toList(),
        'lastSignInAt': now,
        'updatedAt': now,
      };

      if (existingDoc.exists) {
        // Update existing document
        print('DEBUG: Updating existing user document');
        await userRef.update(userData);
      } else {
        // Create new document
        print('DEBUG: Creating new user document');
        userData['createdAt'] = now;
        await userRef.set(userData);
      }

      // Verify document creation/update
      final verifyDoc = await userRef.get();
      if (verifyDoc.exists) {
        final data = verifyDoc.data();
        print('DEBUG: User document verified successfully');
        print('DEBUG: Document fields: ${data?.keys.join(', ')}');
        print('DEBUG: Email in document: ${data?['email']}');
        print('DEBUG: Display name in document: ${data?['displayName']}');
      } else {
        throw Exception('Failed to create user document');
      }

    } catch (e) {
      print('DEBUG: Error creating/updating user document: $e');
      throw Exception('Failed to save user data: $e');
    }
  }

  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (!_isLogin && value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (!_isLogin && (value == null || value.trim().isEmpty)) {
      return 'Please enter your full name';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Logo and Title
                  const Icon(
                    Icons.account_balance_wallet,
                    size: 80,
                    color: Colors.teal,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Money Manager',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin ? 'Welcome back!' : 'Create your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Name Field (Sign Up Only)
                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _nameController,
                      validator: _validateName,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'Enter your full name',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    validator: _validateEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email address',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    validator: _validatePassword,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: _isLogin ? 'Enter your password' : 'Create a password (min 6 characters)',
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _loading ? null : _authenticate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isLogin ? 'Sign In' : 'Create Account',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Toggle Login/Signup
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _isLogin = !_isLogin;
                              // Clear form when switching modes
                              _formKey.currentState?.reset();
                            });
                          },
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.grey),
                        children: [
                          TextSpan(
                            text: _isLogin
                                ? "Don't have an account? "
                                : "Already have an account? ",
                          ),
                          TextSpan(
                            text: _isLogin ? 'Sign Up' : 'Sign In',
                            style: const TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}