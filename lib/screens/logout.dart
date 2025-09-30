import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // << สำคัญ ต้องเพิ่ม

class Logout extends StatelessWidget {
  const Logout({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;

      // ล้างเส้นทางทั้งหมด แล้วกลับหน้าแรก (Login ที่ route '/')
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);

      // หรือถ้าอยากสร้าง Login แบบกำหนดเอง:
      // Navigator.of(context).pushAndRemoveUntil(
      //   MaterialPageRoute(builder: (_) => const Login()),
      //   (route) => false,
      // );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ออกจากระบบไม่สำเร็จ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 229, 22, 174).withAlpha((255 * 0.1).round()),
      body: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 0, 0, 0).withAlpha((255 * 0.1).round()),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Log Out', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('คุณต้องการออกจากระบบใช่หรือไม่?', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                    onPressed: () => _handleLogout(context), // << ใช้ฟังก์ชันด้านบน
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
