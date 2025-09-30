import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app_test/screens/home.dart';

class Login extends StatefulWidget {
  const Login({super.key, this.email = '', this.name = ''});

  final String email;
  final String name;

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _rememberEmail = true; // จำอีเมลไว้ให้
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) print('Login page loaded');
    _loadRememberedEmail();     // เติมอีเมลที่เคยจำไว้
    _autoLoginIfHasSession();   // ถ้ามี session ค้างอยู่ ข้ามไป Home เลย
  }

  /// เติมอีเมลที่เคยบันทึกไว้
  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberEmail = prefs.getBool('remember_email') ?? true;
      emailController.text = prefs.getString('saved_email') ?? '';
    });
  }

  /// ถ้ายังล็อกอินค้างอยู่ ให้ไปหน้า Home ทันที
  void _autoLoginIfHasSession() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final email = user.email ?? '';
      final name = email.contains('@')
          ? email.split('@').first
          : (widget.name.isNotEmpty ? widget.name : 'User');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => Home(name: name, email: email)),
        );
      });
    }
  }

  /// ลืมรหัสผ่าน
  Future<void> _resetPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรอกอีเมลให้ถูกต้องก่อนกดลืมรหัสผ่าน')),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งลิงก์รีเซ็ตรหัสผ่านไปที่อีเมลแล้ว')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'ส่งอีเมลรีเซ็ตไม่สำเร็จ')),
      );
    }
  }

  Future<void> signIn() async {
    // ตรวจพื้นฐาน
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    if (email.isEmpty || !email.contains('@') || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรอกอีเมล/รหัสผ่านให้ครบถ้วน')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // จำอีเมลตามตัวเลือก
      final prefs = await SharedPreferences.getInstance();
      if (_rememberEmail) {
        await prefs.setString('saved_email', email);
        await prefs.setBool('remember_email', true);
      } else {
        await prefs.remove('saved_email');
        await prefs.setBool('remember_email', false);
      }

      // ไปหน้า Home
      final name = email.contains('@') ? email.split('@')[0] : email;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => Home(name: name, email: email)),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg;
      switch (e.code) {
        case 'invalid-email': msg = 'อีเมลไม่ถูกต้อง'; break;
        case 'user-disabled': msg = 'บัญชีถูกปิดการใช้งาน'; break;
        case 'user-not-found': msg = 'ไม่พบบัญชีนี้'; break;
        case 'wrong-password':
        case 'invalid-credential': msg = 'อีเมลหรือรหัสผ่านไม่ถูกต้อง'; break;
        case 'too-many-requests': msg = 'พยายามมากเกินไป กรุณาลองใหม่ภายหลัง'; break;
        case 'network-request-failed': msg = 'เครือข่ายมีปัญหา กรุณาตรวจสอบอินเทอร์เน็ต'; break;
        default: msg = e.message ?? 'เข้าสู่ระบบไม่สำเร็จ';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on PlatformException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เครือข่ายมีปัญหา กรุณาตรวจสอบอินเทอร์เน็ต')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เกิดข้อผิดพลาดที่ไม่คาดคิด')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------- UI helpers ----------------

  InputBorder _purpleBorder() => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color.fromARGB(255, 137, 69, 214),
          width: 1.4,
        ),
      );

  Widget showLogo() => SizedBox(
        width: 160,
        height: 160,
        child: Image.asset('images/logowifi.png'),
      );

  Widget showAppName() => const Text(
        'Internet',
        style: TextStyle(
          fontSize: 35,
          color: Color.fromRGBO(161, 27, 228, 1),
          fontWeight: FontWeight.bold,
        ),
      );

  Widget emailInput() => SizedBox(
        width: 250,
        height: 70,
        child: TextFormField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            labelText: 'Email',
            border: _purpleBorder(),
            enabledBorder: _purpleBorder(),
            focusedBorder: _purpleBorder(),
          ),
        ),
      );

  Widget passwordInput() => SizedBox(
        width: 250,
        height: 70,
        child: TextFormField(
          controller: passwordController,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            labelText: 'Password',
            border: _purpleBorder(),
            enabledBorder: _purpleBorder(),
            focusedBorder: _purpleBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
      );

  Widget rememberRow() => SizedBox(
        width: 250,
        child: Row(
          children: [
            Checkbox(
              value: _rememberEmail,
              onChanged: (v) => setState(() => _rememberEmail = v ?? true),
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            ),
            const Expanded(child: Text('จำอีเมลไว้ให้')),
            TextButton(onPressed: _resetPassword, child: const Text('ลืมรหัสผ่าน?')),
          ],
        ),
      );

  Widget signInButton() => SizedBox(
        width: 200,
        height: 70,
        child: ElevatedButton(
          onPressed: _isLoading ? null : signIn,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 137, 69, 214),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'Sign in',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.white, Colors.white],
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color.fromARGB(0, 156, 29, 29),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    showLogo(),
                    const SizedBox(height: 20),
                    showAppName(),
                    const SizedBox(height: 20),
                    emailInput(),
                    const SizedBox(height: 20),
                    passwordInput(),
                    const SizedBox(height: 8),
                    rememberRow(),
                    const SizedBox(height: 10),
                    signInButton(),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 200,
                      height: 70,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pushNamed(context, 'register'),
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
                          "Sign Up",
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
