import 'package:flutter/material.dart';

class Myprofile extends StatelessWidget {
  final String name;
  final String email;

  const Myprofile({super.key, required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.person, size: 100, color: Colors.deepPurple),
            const SizedBox(height: 24),
            const Text('Name', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            const Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(email, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
