import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_app_test/screens/login.dart'; // ตรวจสอบให้แน่ใจว่า import ถูกต้อง

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passController = TextEditingController();
  final retypePassController = TextEditingController();

  // ฟังก์ชันสมัครสมาชิก
  Future<void> signUp() async {
    debugPrint('---------- Starting signUp function ----------');

    // ตรวจสอบความถูกต้องของฟอร์ม
    if (!formKey.currentState!.validate()) {
      debugPrint('Form validation failed. Please check input fields.');
      return; // ถ้า validation ไม่ผ่าน ให้หยุดฟังก์ชัน
    }
    debugPrint('Form validation passed.');

    try {
      final email = emailController.text.trim();
      final password = passController.text.trim();
      final name = nameController.text.trim();

      debugPrint('Attempting to create user with email: $email');
      // สมัครสมาชิกกับ Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      debugPrint(
        'User created successfully. User UID: ${userCredential.user!.uid}',
      );

      // บันทึกข้อมูลชื่อและอีเมลใน Firestore โดยใช้ UID ของผู้ใช้เป็น Document ID
      debugPrint('Attempting to save user data to Firestore...');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({'name': name, 'email': email});
      debugPrint('User data saved to Firestore successfully.');

      // ตรวจสอบว่า widget ยังคงอยู่บน tree ก่อนทำการ navigate เพื่อป้องกัน error
      if (!mounted) {
        debugPrint('Widget is not mounted, cannot navigate.');
        return;
      }

      // เปลี่ยนไปหน้า Login ทันที
      debugPrint('Attempting to navigate to Login page...');
      try {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Login()),
          (route) => false, // ลบทุก Route ก่อนหน้าออก
        );
        debugPrint('Navigation to Login page initiated successfully.');
      } catch (navError) {
        debugPrint('ERROR: Failed to navigate to Login page: $navError');
        showError('ไม่สามารถเปลี่ยนไปหน้า Login ได้: $navError');
      }
    } on FirebaseAuthException catch (e) {
      // จัดการข้อผิดพลาดที่เกิดจากการสมัครสมาชิกกับ Firebase
      String errorMessage;
      debugPrint(
        'FirebaseAuthException caught: Code: ${e.code}, Message: ${e.message}',
      );
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'รหัสผ่านอ่อนเกินไป กรุณาใช้รหัสผ่านที่แข็งแรงกว่านี้';
          break;
        case 'email-already-in-use':
          errorMessage = 'อีเมลนี้ถูกใช้ไปแล้ว กรุณาใช้อีเมลอื่น';
          break;
        case 'invalid-email':
          errorMessage = 'รูปแบบอีเมลไม่ถูกต้อง';
          break;
        default:
          errorMessage = e.message ?? 'การสมัครสมาชิกไม่สำเร็จ โปรดลองอีกครั้ง';
          break;
      }
      showError(errorMessage);
    } catch (e) {
      // จัดการข้อผิดพลาดอื่น ๆ ที่อาจเกิดขึ้น
      debugPrint('Unexpected error caught: $e');
      showError('เกิดข้อผิดพลาดที่ไม่คาดคิด: $e');
    }
    debugPrint('---------- signUp function finished ----------');
  }

  // ฟังก์ชันแสดงข้อความ error โดยใช้ SnackBar
  void showError(String message) {
    // ตรวจสอบว่า context ยัง mounted ก่อนแสดง SnackBar
    if (!mounted) {
      debugPrint('Cannot show SnackBar, context is not mounted.');
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // Widget สำหรับสร้างช่องกรอกข้อมูล
  Widget buildInputField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    String? Function(String?)? validator,
  }) {
    return SizedBox(
      width: 350,
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        validator: validator,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          labelText: label,
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromARGB(255, 255, 255, 255),
            Color.fromARGB(255, 200, 200, 255),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Form(
            key: formKey,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: 50.0,
                        color: Color.fromRGBO(137, 69, 214, 1),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 70),
                    buildInputField(
                      controller: nameController,
                      label: 'Your name',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณากรอกชื่อของคุณ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    buildInputField(
                      controller: emailController,
                      label: 'Your E-Mail',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณากรอกอีเมลของคุณ';
                        } else if (!value.contains('@')) {
                          return 'รูปแบบอีเมลไม่ถูกต้อง';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    buildInputField(
                      controller: passController,
                      label: 'Create your Password',
                      obscure: true,
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'รหัสผ่านต้องมีความยาวอย่างน้อย 6 ตัวอักษร';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    buildInputField(
                      controller: retypePassController,
                      label: 'Re-Type your Password',
                      obscure: true,
                      validator: (value) {
                        if (value != passController.text) {
                          return 'รหัสผ่านไม่ตรงกัน';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: 200,
                      height: 60,
                      child: ElevatedButton(
                        onPressed:
                            signUp, // เรียกใช้ฟังก์ชัน signUp เมื่อกดปุ่ม
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: const BorderSide(
                              color: Color.fromARGB(255, 137, 69, 214),
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Sign up',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 137, 69, 214),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
