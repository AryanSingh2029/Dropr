import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
// hiiiiiiii
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool isLogin = true;
  bool isLoading = false;
  final nameController = TextEditingController();
  final regNoController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool checkingLogin = true; // 👈 we'll use this to show loader while checking auth
  @override
  void initState() {
    super.initState();
    _checkIfLoggedIn();
  }

  void _checkIfLoggedIn() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && user.emailVerified) {
      // Already logged in and verified
      Future.delayed(Duration.zero, () {
        Navigator.pushReplacementNamed(context, '/role');
      });
    } else {
      setState(() {
        checkingLogin = false;
      });
    }
  }

  // ✅ Use instanceFor with correct databaseURL
  final DatabaseReference _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://dropbuddy-506d3-default-rtdb.asia-southeast1.firebasedatabase.app',
  ).ref("users");

  @override
  Widget build(BuildContext context) {
    if (checkingLogin) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLogin ? 'Welcome Back' : 'Register with your VIT email',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        _tabButton("Login", isLogin),
                        _tabButton("Sign Up", !isLogin),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!isLogin) ...[
                    _buildInput("Full Name", nameController),
                    const SizedBox(height: 16),
                    _buildInput("Registration Number", regNoController),
                    const SizedBox(height: 16),
                    _buildInput("Phone Number", phoneController, keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                  ],
                  _buildInput("VIT Email (without @vitstudent.ac.in)", emailController),
                  const SizedBox(height: 16),
                  _buildInput("Password", passwordController, isPassword: true),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLogin ? _login : _signup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(isLogin ? 'Login' : 'Sign Up'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        isLogin = !isLogin;
                      });
                    },
                    child: RichText(
                      text: TextSpan(
                        text: isLogin ? "Don't have an account? " : "Already have an account? ",
                        style: const TextStyle(color: Colors.grey),
                        children: [
                          TextSpan(
                            text: isLogin ? "Sign Up" : "Login",
                            style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isLoading && isLogin)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  void _signup() async {
    final name = nameController.text.trim();
    final reg = regNoController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    final fullEmail = "$email@vitstudent.ac.in";

    if (name.isEmpty || reg.isEmpty || phone.length != 10 || email.isEmpty || password.length < 6) {
      _showError("Please fill all fields correctly (password should be ≥ 6 chars)");
      return;
    }

    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: fullEmail, password: password);

      await _db.child(cred.user!.uid).set({
        'name': name,
        'registration': reg,
        'phone': phone,
        'email': fullEmail,
      });

      await cred.user!.sendEmailVerification();

      _showMessage("Registered successfully. Check your inbox or spam and please Verify email to continue.");
    } catch (e) {
      _showError("Signup failed: ${e.toString().split(']').last}");
    }
  }

  void _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    final fullEmail = "$email@vitstudent.ac.in";
    setState(() => isLoading = true); // 👈 show loader
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: fullEmail, password: password);

      if (!cred.user!.emailVerified) {
        setState(() => isLoading = false); // 👈 hide loader
        _showError("Please verify your email before logging in.");
        return;
      }

      _showMessage("Login successful!");
      await Future.delayed(const Duration(milliseconds: 500)); // 👈 gives loader time to show
      setState(() => isLoading = false); // 👈 hide loader before navigating
      Navigator.pushNamed(context, '/role');
    } catch (e) {
      setState(() => isLoading = false); // 👈 hide loader on error too
      _showError("Login failed: ${e.toString().split(']').last}");
    }
  }

  Widget _buildInput(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text, bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: "Enter $label",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ],
    );
  }

  Expanded _tabButton(String text, bool selected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => isLogin = (text == "Login")),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: selected ? Colors.black : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
}
