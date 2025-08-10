import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_test/screens/home.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Login extends StatefulWidget {
  const Login({super.key, this.email = '', this.name = ''});

  final String email;
  final String name;

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('Login page loaded');
    }
  }

  Future<void> signIn() async {
    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      String name = email.contains('@') ? email.split('@')[0] : email;

      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Home(name: name, email: email)),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? 'Login failed')));
    }
  }

  Widget showLogo() {
    return SizedBox(
      width: 160.0,
      height: 160.0,
      child: Image.asset('images/logowifi.png'),
    );
  }

  Widget showAppName() {
    return const Text(
      'Internet',
      style: TextStyle(
        fontSize: 35.0,
        color: Color.fromRGBO(161, 27, 228, 1),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget emailInput() {
    return SizedBox(
      width: 250,
      height: 70,
      child: TextFormField(
        controller: emailController,
        decoration: const InputDecoration(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(),
          labelText: 'Email',
        ),
      ),
    );
  }

  Widget passwordInput() {
    return SizedBox(
      width: 250,
      height: 70,
      child: TextFormField(
        controller: passwordController,
        obscureText: true,
        decoration: const InputDecoration(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(),
          labelText: 'Password',
        ),
      ),
    );
  }

  Widget signInButton() {
    return SizedBox(
      width: 200,
      height: 70,
      child: ElevatedButton(
        onPressed: signIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 137, 69, 214),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: const Text(
          'Sign in',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Color.fromARGB(255, 255, 255, 255),
            Color.fromARGB(255, 255, 255, 255),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color.fromARGB(0, 156, 29, 29),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
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
                  const SizedBox(height: 20),
                  signInButton(),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 200,
                    height: 70,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, 'register');
                      },
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
    );
  }
}
