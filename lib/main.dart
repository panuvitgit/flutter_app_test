import 'package:flutter/material.dart';
import 'package:flutter_app_test/screens/login.dart';
import 'package:flutter_app_test/screens/register.dart';
import 'package:flutter_app_test/screens/logout.dart';
import 'package:flutter_app_test/screens/switchbutton.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter App Test',
      initialRoute: '/',
      routes: {
        '/': (context) => const Login(),
        'register': (context) => const Register(),
        'logout': (context) => const Logout(),
        'switchbutton': (context) => const Switchbutton(),
      },
    );
  }
}
