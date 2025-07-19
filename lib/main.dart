import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (e.toString().contains('already exists')) {
      debugPrint('⚠️ Firebase already initialized. Skipping reinitialization.');
    } else {
      rethrow; // Crash if it's a real error
    }
  }

  runApp(const DropBuddyApp());
}

class DropBuddyApp extends StatelessWidget {
  const DropBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Buddy',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: appRoutes,
    );
  }
}
