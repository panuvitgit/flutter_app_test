import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Screens
import 'package:flutter_app_test/screens/login.dart';
import 'package:flutter_app_test/screens/register.dart';
import 'package:flutter_app_test/screens/logout.dart';
import 'package:flutter_app_test/screens/switchbutton.dart';
import 'package:flutter_app_test/screens/chart_day.dart';
import 'package:flutter_app_test/screens/chart_week.dart';
import 'package:flutter_app_test/screens/chart_month.dart';
import 'package:flutter_app_test/screens/chart_year.dart';
import 'package:flutter_app_test/screens/snapshot_page.dart';


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
        // Home / Auth
        '/': (context) => const Login(),
        '/register': (context) => const Register(),
        '/logout': (context) => const Logout(),
        '/switchbutton': (context) => const Switchbutton(),

        // Compatibility with existing calls without leading slash
        'register': (context) => const Register(),
        'logout': (context) => const Logout(),
        'switchbutton': (context) => const Switchbutton(),

        // Daily chart route
        '/chart_day': (context) => const ChartDay(),
        '/chart_week': (context) => const ChartWeek(),
        '/chart_month': (context) => const ChartMonth(),
        '/chart_year': (context) => const ChartYear(),
        '/snapshot': (context) => const SnapshotPage()

      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: Center(child: Text('Route not found')),
        ),
      ),
    );
  }
}
