import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class Switchbutton extends StatefulWidget {
  const Switchbutton({super.key});

  @override
  State<Switchbutton> createState() => _SwitchbuttonState();
}

class _SwitchbuttonState extends State<Switchbutton>
    with SingleTickerProviderStateMixin {
  bool isOn = false;
  final dbRef = FirebaseDatabase.instance.ref('device1/status');

  double _scale = 1.0;

  @override
  void initState() {
    super.initState();

    dbRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is String) {
        setState(() {
          isOn = (data == 'on');
        });
      }
    });
  }

  void _updateStatus(bool value) {
    final newStatus = value ? 'on' : 'off';
    dbRef.set(newStatus);
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _scale = 0.9;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _scale = 1.0;
    });
  }

  void _onTapCancel() {
    setState(() {
      _scale = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Light Control'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  isOn = !isOn;
                });
                _updateStatus(isOn);
              },
              onTapDown: _onTapDown,
              onTapUp: _onTapUp,
              onTapCancel: _onTapCancel,
              child: AnimatedScale(
                scale: _scale,
                duration: const Duration(milliseconds: 100),
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color:
                        isOn
                            ? Colors.greenAccent.shade700
                            : const Color.fromRGBO(116, 114, 114, 1),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.power_settings_new,
                      color: Colors.white,
                      size: 100,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              isOn ? 'สถานะ: ON' : 'สถานะ: OFF',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color:
                    isOn
                        ? Colors.green
                        : const Color.fromRGBO(116, 114, 114, 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
