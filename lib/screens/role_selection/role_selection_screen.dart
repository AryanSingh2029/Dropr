import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}
class FeedbackDialog extends StatefulWidget {
  const FeedbackDialog({super.key});

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final TextEditingController _controller = TextEditingController();
  bool isSubmitting = false;

  void submitFeedback() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    setState(() => isSubmitting = true);

    final ref = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://dropbuddy-506d3-default-rtdb.asia-southeast1.firebasedatabase.app',
    ).ref('feedback').push();

    await ref.set({
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });

    setState(() => isSubmitting = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Feedback submitted anonymously!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Give Anonymous Feedback"),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        decoration: const InputDecoration(hintText: "Write your thoughts..."),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: isSubmitting ? null : submitFeedback,
          child: Text(isSubmitting ? "Submitting..." : "Submit"),
        ),
      ],
    );
  }
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String uid = '';
  List<Map<String, dynamic>> allRequests = [];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      uid = user.uid;
      fetchRequests();
    }
  }

  void fetchRequests() async {
    final ref = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://dropbuddy-506d3-default-rtdb.asia-southeast1.firebasedatabase.app',
    ).ref().child('requests');

    final snapshot = await ref.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map;
      List<Map<String, dynamic>> fetched = [];
      data.forEach((key, value) {
        final map = Map<String, dynamic>.from(value);
        map['id'] = key;
        fetched.add(map);
      });
      setState(() {
        allRequests = fetched;
      });
    }
  }

  bool hasNeedrTask() {
    return allRequests.any((r) =>
    r['needrId'] == uid &&
        (r['status'] == 'pending' ||
            r['status'] == 'accepted' ||
            r['status'] == 'awaiting_confirmation'));
  }

  bool hasDroprTask() {
    return allRequests.any((r) =>
    r['droprId'] == uid &&
        (r['status'] == 'accepted' ||
            r['status'] == 'awaiting_confirmation'));
  }

  void showBlockMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Role', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView( // ✅ Wrap with scrollable view
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              // 🔹 Dropr Card
              _buildRoleCard(
                context,
                title: "Dropr",
                description: "Help your peers by accepting delivery requests.",
                icon: Icons.local_shipping,
                onTap: () {
                  if (hasNeedrTask()) {
                    showBlockMessage("❌ You have an active Receivr task. Please complete it first.");
                  } else {
                    Navigator.pushNamed(context, '/dropr-home');
                  }
                },
              ),

              const SizedBox(height: 24),

              // 🔹 Needr Card
              _buildRoleCard(
                context,
                title: "Receivr",
                description: "Request help from peers for delivering your items.",
                icon: Icons.person_search,
                onTap: () {
                  if (hasDroprTask()) {
                    showBlockMessage("❌ You have an active Dropr task. Please complete it first.");
                  } else {
                    Navigator.pushNamed(context, '/needr-home');
                  }
                },
              ),

              const SizedBox(height: 30),

              // 🔽 App Description at bottom
              const Text(
                "What is DropBuddy?",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "DropBuddy is a student-to-student delivery help app.\n\n"
                    "📦 Need something picked up? Be a Receivr.\n"
                    "🚚 Want to help and earn goodwill? Be a Dropr.\n\n"
                    "Smart, safe, and efficient way to assist each other inside campus.",
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 30),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const FeedbackDialog(), // we define this next
                    );
                  },
                  icon: Icon(Icons.feedback),
                  label: Text("Give Feedback"),
                ),
              ),

            const SizedBox(height: 16),

// 🔔 Notification message
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("🔔 ", style: TextStyle(fontSize: 18)),
                  Expanded(
                    child: Text(
                      "Heads up! Notifications are coming soon — for now, kindly revisit this screen to stay updated on your request status.",
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
           ],
          ),
        ),
      ),
    );
  }
  Widget _buildRoleCard(
      BuildContext context, {
        required String title,
        required String description,
        required IconData icon,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Colors.black,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Icon(icon, size: 30, color: Colors.black),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(description,
                        style:
                        const TextStyle(fontSize: 14, color: Colors.white70)),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
//trying