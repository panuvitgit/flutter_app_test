import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_app_test/screens/login.dart';

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

  bool _isSubmitting = false;

  Future<void> signUp() async {
    if (!formKey.currentState!.validate()) return;
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final email = emailController.text.trim();
    final password = passController.text.trim();
    final name = nameController.text.trim();

    try {
      // 1) สมัครสมาชิกให้สำเร็จก่อน
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // 2) พยายามบันทึกโปรไฟล์ (ถ้าเขียนไม่ได้ก็ไม่ขวางการนำทาง)
      FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set({'name': name, 'email': email})
          .catchError((e) {
        debugPrint('Save profile failed (will still navigate): $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('สมัครสำเร็จ แต่บันทึกโปรไฟล์ไม่สำเร็จ'),
            ),
          );
        }
      });

      // 3) ออกจากระบบ แล้วพาไปหน้า Login พร้อมส่งอีเมลไปเติมให้
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => Login(email: email)),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'weak-password':
          msg = 'รหัสผ่านอ่อนเกินไป กรุณาใช้รหัสผ่านที่แข็งแรงกว่านี้';
          break;
        case 'email-already-in-use':
          msg = 'อีเมลนี้ถูกใช้ไปแล้ว กรุณาใช้อีเมลอื่น';
          break;
        case 'invalid-email':
          msg = 'รูปแบบอีเมลไม่ถูกต้อง';
          break;
        default:
          msg = e.message ?? 'การสมัครสมาชิกไม่สำเร็จ โปรดลองอีกครั้ง';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดที่ไม่คาดคิด: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

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
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passController.dispose();
    retypePassController.dispose();
    super.dispose();
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
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'กรุณากรอกชื่อของคุณ' : null,
                    ),
                    const SizedBox(height: 30),
                    buildInputField(
                      controller: emailController,
                      label: 'Your E-Mail',
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'กรุณากรอกอีเมลของคุณ';
                        if (!v.contains('@')) return 'รูปแบบอีเมลไม่ถูกต้อง';
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    buildInputField(
                      controller: passController,
                      label: 'Create your Password',
                      obscure: true,
                      validator: (v) =>
                          (v == null || v.length < 6)
                              ? 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร'
                              : null,
                    ),
                    const SizedBox(height: 30),
                    buildInputField(
                      controller: retypePassController,
                      label: 'Re-Type your Password',
                      obscure: true,
                      validator: (v) =>
                          (v != passController.text) ? 'รหัสผ่านไม่ตรงกัน' : null,
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: 200,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : signUp,
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
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
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
