import 'package:flutter/material.dart';
import 'package:flutter_app_test/screens/myprofile.dart';
import 'package:flutter_app_test/screens/switchbutton.dart';
import 'package:flutter_app_test/screens/videostreaming.dart';
import 'package:flutter_app_test/screens/dashboard.dart';

class Home extends StatelessWidget {
  final String name;
  final String email;

  const Home({super.key, required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[100],
        title: const Text('Home', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                name,
                style: const TextStyle(color: Colors.black),
              ),
              accountEmail: Text(
                email,
                style: const TextStyle(color: Colors.black54),
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundImage: AssetImage('images/logowifi.png'),
              ),
              decoration: const BoxDecoration(color: Colors.white),
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.black),
              title: const Text(
                "My Profile",
                style: TextStyle(color: Colors.black),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Myprofile(name: name, email: email),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Log Out", style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.canPop(context);
                Navigator.pushNamed(context, 'logout');
              },
            ),
          ],
        ),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 25),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFE0E0E0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          children: [
            buildModernCard(
              context,
              icon: Icons.toggle_on_outlined,
              label: "Switch Button",
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const Switchbutton()),
                  ),
            ),
            const SizedBox(height: 47),
            buildModernCard(
              context,
              icon: Icons.bar_chart_outlined,
              label: "Dashboard",
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DashboardPage()),
                  ),
            ),
            const SizedBox(height: 47),
            buildModernCard(
              context,
              icon: Icons.videocam_outlined,
              label: "Video Streaming",
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VideoStreamingPage(),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildModernCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40),
          alignment: Alignment.center,
          child: Column(
            children: [
              Icon(icon, size: 70, color: Colors.black),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
