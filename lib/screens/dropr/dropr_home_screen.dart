import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:campus_buddy/screens/auth/welcome_screen.dart';
import 'package:campus_buddy/screens/role_selection/role_selection_screen.dart';
import 'package:campus_buddy/screens/chat/chat_screen.dart';

class DroprHomeScreen extends StatefulWidget {
  const DroprHomeScreen({super.key});

  @override
  State<DroprHomeScreen> createState() => _DroprHomeScreenState();
}

class _DroprHomeScreenState extends State<DroprHomeScreen> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> allRequests = [];
  List<Map<String, String>> chats = []; // Store chatId + otherUserName

  String name = '';
  String phone = '';
  String email = '';
  String uid = '';
  bool isUpdating = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      uid = user.uid;
      fetchUserProfile();
      listenToRequests();
      fetchMyChats();
    }
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
        final participants = chat['participants'] as Map?;

        if (participants != null && participants[uid] == true) {
          final otherId = participants.keys.firstWhere((id) => id != uid, orElse: () => '');

          // 🔍 Fetch actual name from users/{otherId}
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

  Future<void> acceptRequest(String requestId) async {
    setState(() => isUpdating = true);

    try {
      final ref = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://dropbuddy-506d3-default-rtdb.asia-southeast1.firebasedatabase.app',
      ).ref().child('requests').child(requestId);

      await ref.update({
        'droprId': uid,
        'droprName': name,
        'droprPhone': phone,
        'status': 'accepted',
      });
    } finally {
      setState(() => isUpdating = false);
    }
  }

  Future<void> markAsDelivered(String requestId) async {
    setState(() => isUpdating = true);

    try {
      final ref = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://dropbuddy-506d3-default-rtdb.asia-southeast1.firebasedatabase.app',
      ).ref().child('requests').child(requestId);

      await ref.update({'status': 'awaiting_confirmation'});
    } finally {
      setState(() => isUpdating = false);
    }
  }


  Widget buildDashboard() {
    final pending = allRequests.where((r) => r['status'] == 'pending').toList();

    if (pending.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Dropr Dashboard", style: TextStyle(fontSize: 20)),
            SizedBox(height: 8),
            Text("No requests available right now. Keep checking!", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: pending.map((request) {
        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Pickup: ${request['pickup']}"),
                Text("Drop: ${request['drop']}"),
                Text("Package: ${request['description']}"), // ✅ Add this
                Text("Name: ${request['needrName']}"),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () async => await acceptRequest(request['id']),
                      child: const Text("Accept"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        FirebaseDatabase.instanceFor(
                          app: Firebase.app(),
                          databaseURL: 'https://dropbuddy-506d3-default-rtdb.asia-southeast1.firebasedatabase.app',
                        ).ref().child('requests').child(request['id']).remove();
                      },
                      child: const Text("Don't Accept"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget buildActiveOrders() {
    final active = allRequests.where((r) =>
    r['droprId'] == uid && (r['status'] == 'accepted' || r['status'] == 'awaiting_confirmation')).toList();

    if (active.isEmpty) {
      return const Center(child: Text("No active orders yet."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: active.length,
      itemBuilder: (context, index) {
        final request = active[index];
        final awaiting = request['status'] == 'awaiting_confirmation';
        final needrId = request['needrId'];

        return FutureBuilder(
          future: FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: 'https://dropbuddy-506d3-default-rtdb.asia-southeast1.firebasedatabase.app',
          ).ref().child('users').child(needrId).get(),
          builder: (context, snapshot) {
            String needrPhone = 'N/A';

            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
              final data = snapshot.data?.value as Map?;
              if (data != null && data.containsKey('phone')) {
                needrPhone = data['phone'];
              }
            }

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
                    Text("Package: ${request['description']}"), // ✅ Add this line
                    Text("Name: ${request['needrName']}"),
                    Text("Phone: $needrPhone"),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            final chatId = getChatId(uid, needrId);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  chatId: chatId,
                                  otherUserName: request['needrName'],
                                ),
                              ),
                            );
                          },
                          child: const Text("Chat with Receivr"),
                        ),
                        ElevatedButton(
                          onPressed: awaiting ? null : () async => await markAsDelivered(request['id']),

                          style: ElevatedButton.styleFrom(
                            backgroundColor: awaiting ? Colors.purple : Colors.orange,
                          ),
                          child: Text(awaiting ? "Hold" : "Mark as Delivered"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildHistory() {
    final completed = allRequests.where((r) =>
    r['droprId'] == uid && (r['status'] == 'completed')).toList();

    final ongoing = allRequests.where((r) =>
    r['droprId'] == uid && (r['status'] == 'accepted' || r['status'] == 'awaiting_confirmation')).toList();

    final combined = [...ongoing, ...completed];

    if (combined.isEmpty) {
      return const Center(child: Text("No past or current orders."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: combined.length,
      itemBuilder: (context, index) {
        final request = combined[index];
        final status = request['status'];

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Pickup: ${request['pickup']}"),
                Text("Drop: ${request['drop']}"),
                Text("Package: ${request['description']}"),
                Text("Receivr: ${request['needrName']}"),
                const SizedBox(height: 10),
                Text(
                  status == 'completed' ? "Status: Completed ✅"
                      : status == 'awaiting_confirmation' ? "Status: Awaiting Needr Confirmation 🕓"
                      : "Status: In Progress 🔄",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildProfile() {
    final hasActive = allRequests.any((r) =>
    r['droprId'] == uid && (r['status'] == 'accepted' || r['status'] == 'awaiting_confirmation'));

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
                    value: true,
                    onChanged: (_) {
                      if (hasActive) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("❗ Please complete the ongoing task to switch roles."),
                            backgroundColor: Colors.redAccent,
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
      buildActiveOrders(),
      buildHistory(),
      buildProfile(),
    ];
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 240, 245),
      appBar: AppBar(
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
        toolbarHeight: 65,
        title: const Text(
          'Role: Dropr\nThanks for helping your peers',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white,
            height: 1.3,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Stack(
        children: [
          pages[_selectedIndex],
          if (isUpdating)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      "Updating request status...",
                      style: TextStyle(color: Colors.white),
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Active'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'history'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

String getChatId(String uid1, String uid2) {
  final ids = [uid1, uid2]..sort();
  return ids.join('_');
}
