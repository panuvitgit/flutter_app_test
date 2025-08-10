import 'package:flutter/material.dart';
import 'package:flutter_app_test/screens/login.dart';

class Logout extends StatelessWidget {
  const Logout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(
        255,
        229,
        22,
        174,
      ).withAlpha((255 * 0.1).round()),
      body: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Color.fromARGB(
                  255,
                  0,
                  0,
                  0,
                ).withAlpha((255 * 0.1).round()),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Log Out',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'คุณต้องการออกจากระบบใช่หรือไม่?',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(
                        255,
                        255,
                        255,
                        255,
                      ), // ขาว
                      foregroundColor: const Color.fromARGB(255, 0, 0, 0), // ดำ
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                      foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                    ),
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const Login()),
                        (route) => false,
                      );
                    },
                    child: const Text('YES'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
