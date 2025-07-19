// ✅ Final updated NeedrHomeScreen with active order logic based on DB status

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:campus_buddy/screens/auth/welcome_screen.dart';
import 'package:campus_buddy/screens/role_selection/role_selection_screen.dart';
import 'package:campus_buddy/screens/chat/chat_screen.dart';
String getChatId(String uid1, String uid2) {
  final ids = [uid1, uid2]..sort(); // sort alphabetically to ensure same chatId for both
  return ids.join('_');
}

class NeedrHomeScreen extends StatefulWidget {
  const NeedrHomeScreen({super.key});

  @override
  State<NeedrHomeScreen> createState() => _NeedrHomeScreenState();
}

class _NeedrHomeScreenState extends State<NeedrHomeScreen> {
  int _selectedIndex = 0;
  List<Map<String, String>> chats = [];
  List<Map<String, dynamic>> allRequests = [];

  String name = '';
  String phone = '';
  String email = '';
  String uid = '';

  final _formKey = GlobalKey<FormState>();
  String selectedPickup = 'Main Gate';
  String customPickup = '';
  bool useCustomPickup = false;
  String description = '';
  String dropPoint = '';
  bool isSearching = false;
  bool droprFound = false;
  bool awaitingConfirmation = true;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      uid = user.uid;
      fetchUserProfile();
      listenToRequests();
      fetchMyChats(); // ✅ <-- add this
    }
  }
  void fetchMyChats() async {
    final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://dropbuddy-506d3-default-rtdb.asia-southeast1.firebasedatabase.app',
    ).ref().child('chats');

    db.onValue.listen((event) async {
      final data = event.snapshot.value as Map?;
      if (data == null) return;

      List<Map<String, String>> fetched = [];

      for (final entry in data.entries) {
        final chatId = entry.key;
        final chat = entry.value as Map;
        final participants = (chat['participants'] as Map<String, dynamic>?);

        if (participants != null && participants[uid] == true) {
          final otherId = participants.keys
              .whereType<String>()
              .firstWhere((id) => id != uid, orElse: () => '');

          final userSnap = await FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: 'https://dropbuddy-506d3-default-rtdb.asia-southeast1.firebasedatabase.app',
          ).ref().child('users').child(otherId).get();

          final name = userSnap.exists ? (userSnap.value as Map)['name'] ?? otherId : otherId;

          fetched.add({
            'chatId': chatId,
            'otherUserName': name,
          });
        }

      }

      setState(() {
        chats = fetched;
      });
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void fetchUserProfile() async {
    final userRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://dropbuddy-506d3-default-rtdb.asia-southeast1.firebasedatabase.app',
    ).ref().child('users').child(uid);

    final snapshot = await userRef.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map;
      setState(() {
        name = data['name'] ?? '';
        phone = data['phone'] ?? '';
        email = data['email'] ?? '';
      });
    }
  }

  void listenToRequests() {
    final ref = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://dropbuddy-506d3-default-rtdb.asia-southeast1.firebasedatabase.app',
    ).ref().child('requests');

    ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null) return;
      final Map raw = data as Map;
      List<Map<String, dynamic>> fetched = [];
      raw.forEach((key, value) {
        final map = Map<String, dynamic>.from(value);
        map['id'] = key;
        fetched.add(map);
      });
      setState(() {
        allRequests = fetched;
      });
    });
  }

  Future<void> confirmDelivery(String requestId) async {
    final ref = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://dropbuddy-506d3-default-rtdb.asia-southeast1.firebasedatabase.app',
    ).ref().child('requests').child(requestId);

    await ref.update({'status': 'completed'});
    setState(() {});
  }

  Widget buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.black12,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("Please follow these rules:", style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text("- Drop point should be within college or near campus gate."),
                  Text("- The app is to help students help each other."),
                  Text("- If a student takes a shuttle, discuss prior and agree to pay shuttle price."),
                  Text("- Be fair and ensure a good experience."),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text("Create a Request", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: selectedPickup,
                  decoration: const InputDecoration(labelText: "Pickup Location"),
                  items: ["Main Gate", "Allmart", "2nd Gate", "Amazon", "Custom"]
                      .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedPickup = value!;
                      useCustomPickup = value == 'Custom';
                    });
                  },
                ),
                if (useCustomPickup)
                  TextFormField(
                    decoration: const InputDecoration(labelText: "Enter Custom Pickup Location"),
                    onChanged: (value) => customPickup = value,
                  ),
                const SizedBox(height: 10),
                TextFormField(
                  decoration: const InputDecoration(labelText: "Package Description"),
                  onChanged: (value) => description = value,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  decoration: const InputDecoration(labelText: "Drop Point"),
                  onChanged: (value) => dropPoint = value,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Price: ₹20", style: TextStyle(fontWeight: FontWeight.bold)),
                    ElevatedButton(
                      onPressed: () async {
                        final alreadyHasRequest = allRequests.any((r) =>
                        r['needrId'] == uid &&
                            (r['status'] == 'pending' || r['status'] == 'accepted' || r['status'] == 'awaiting_confirmation')
                        );

                        if (alreadyHasRequest) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("⚠️ You already have an active or searching request. Please complete or cancel it first."),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }

                        if (_formKey.currentState!.validate()) {
                          setState(() => isLoading = true); //
                          final db = FirebaseDatabase.instanceFor(
                            app: Firebase.app(),
                            databaseURL: 'https://dropbuddy-506d3-default-rtdb.asia-southeast1.firebasedatabase.app',
                          ).ref();

                          setState(() {
                            isSearching = true;
                          });

                          try {
                            await db.child('requests').push().set({
                              'needrId': uid,
                              'needrName': name,
                              'pickup': useCustomPickup ? customPickup : selectedPickup,
                              'drop': dropPoint,
                              'description': description,
                              'price': 20,
                              'status': 'pending',
                              'droprId': '',
                              'droprName': '',
                              'droprPhone': '',
                            });
                            await Future.delayed(const Duration(milliseconds: 500)); // optional pause to show loader
                            setState(() => isLoading = false); // 👈 Hide loader

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("✅ Request noted! We’re searching for a Dropr..."),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          } catch (e) {
                            setState(() {
                              setState(() => isLoading = false); // hide loader on error too
                              isSearching = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("❌ Failed to create request: $e")),
                            );
                          }
                        }
                      },
                      child: const Text("Start Searching for Dropr"),
                    )
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildActiveRequests() {
    final active = allRequests.where((r) =>
    r['needrId'] == uid && (r['status'] == 'accepted' || r['status'] == 'awaiting_confirmation')
    ).toList();

    if (active.isEmpty) {
      return const Center(child: Text("No active orders yet."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: active.length,
      itemBuilder: (context, index) {
        final request = active[index];
        final awaiting = request['status'] == 'awaiting_confirmation';

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Pickup: ${request['pickup']}"),
                Text("Drop: ${request['drop']}"),
                Text("Package: ${request['description']}"),
                Text("Dropr: ${request['droprName']}"),
                Text("Phone: ${request['droprPhone']}"),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    final droprId = request['droprId'];
                    final droprName = request['droprName'];
                    final chatId = getChatId(uid, droprId);

                    final db = FirebaseDatabase.instanceFor(
                      app: Firebase.app(),
                      databaseURL: 'https://dropbuddy-506d3-default-rtdb.asia-southeast1.firebasedatabase.app',
                    ).ref();

                    // ✅ Create chat entry with participants
                    await db.child('chats').child(chatId).update({
                      'participants': {
                        uid: true,
                        droprId: true,
                      }
                    });
                 //   fetchMyChats(); // 🔄 Manually refresh chat list

                    // ✅ Navigate to ChatScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          chatId: chatId,
                          otherUserName: droprName,
                        ),
                      ),
                    );
                  },
                  child: const Text("Chat with Dropr"),
                ),

                const SizedBox(height: 12),
                if (awaiting)
                  ElevatedButton(
                    onPressed: () => confirmDelivery(request['id']),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text("Confirm Package Received"),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildHistory() {
    final myRequests = allRequests.where((r) => r['needrId'] == uid).toList().reversed.toList();

    if (myRequests.isEmpty) {
      return const Center(child: Text("No requests placed yet."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: myRequests.length,
      itemBuilder: (context, index) {
        final req = myRequests[index];
        final status = req['status'];
        final isPending = status == 'pending';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text("To: ${req['drop']} | Status: $status"),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Pickup: ${req['pickup']}"),
                Text("Package: ${req['description']}"),
                Text("Dropr: ${req['droprName']}"),
              ],
            ),
            trailing: isPending
                ? IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () async {
                final id = req['id'];
                await FirebaseDatabase.instanceFor(
                  app: Firebase.app(),
                  databaseURL:
                  'https://dropbuddy-506d3-default-rtdb.asia-southeast1.firebasedatabase.app',
                ).ref().child('requests').child(id).remove();
              },
            )
                : null,
          ),
        );
      },
    );
  }


  Widget buildProfile() {
    final hasActive = allRequests.any((r) =>
    r['needrId'] == uid &&
        (r['status'] == 'accepted' || r['status'] == 'pending'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Profile", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text("Name", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(name),
          const SizedBox(height: 10),
          const Text("Phone", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(phone),
          const SizedBox(height: 10),
          const Text("Email", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(email),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Switch Role", style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  const Text("Receivr"),
                  Switch(
                    value: false, // ✅ OFF = currently in Needr
                    onChanged: (_) {
                      if (hasActive) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("⚠️ Please finish your current request to switch roles."),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } else {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                        );
                      }
                    },
                  ),
                  const Text("Dropr"),
                ],
              ),
            ],
          ),
          const SizedBox(height: 30),
          Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final shouldLogout = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Confirm Logout"),
                      content: const Text("Are you sure you want to logout?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("Logout", style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );

                  if (shouldLogout == true) {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                          (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text("Logout"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      buildDashboard(),
      buildActiveRequests(),
      buildHistory(),
      buildProfile(),
    ];

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 240, 245),
      appBar: AppBar(
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
        title: const Text(
          'Role: Receivr\nRequest help from droprs',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        toolbarHeight: 65,
      ),
      body: Stack(
        children: [
          pages[_selectedIndex],

          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Adding request to Order History...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.black,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
        items:  [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Active'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}