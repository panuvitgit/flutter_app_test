import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class Switchbutton extends StatefulWidget {
  const Switchbutton({super.key});

  @override
  State<Switchbutton> createState() => _SwitchbuttonState();
}

class _SwitchbuttonState extends State<Switchbutton> {
  bool isOn = false;
  bool _busy = false; // กันการกดรัวระหว่างเขียนค่า
  final DatabaseReference dbRef =
      FirebaseDatabase.instance.ref('device1/status');

  double _scale = 1.0;

  StreamSubscription<DatabaseEvent>? _sub; // << สำคัญ: เก็บ subscription

  @override
  void initState() {
    super.initState();

    _sub = dbRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is String) {
        final next = (data.toLowerCase() == 'on');
        // อัปเดตเฉพาะเมื่อค่าต่างจากเดิม และต้องยัง mounted
        if (mounted && next != isOn) {
          setState(() {
            isOn = next;
          });
        }
      }
    });
  }

  Future<void> _updateStatus(bool value) async {
    // กันการกดซ้ำเร็ว ๆ ระหว่างกำลังเขียน
    if (mounted) {
      setState(() => _busy = true);
    }
    try {
      await dbRef.set(value ? 'on' : 'off');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _onTapDown(TapDownDetails details) {
    if (!mounted) return;
    setState(() {
      _scale = 0.9;
    });
  }

  void _onTapUp(TapUpDetails details) {
    if (!mounted) return;
    setState(() {
      _scale = 1.0;
    });
  }

  void _onTapCancel() {
    if (!mounted) return;
    setState(() {
      _scale = 1.0;
    });
  }

  @override
  void dispose() {
    // << สำคัญมาก: ยกเลิกการฟังจาก Firebase
    _sub?.cancel();
    _sub = null;
    super.dispose();
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
              onTap: _busy
                  ? null
                  : () {
                      // สลับสถานะใน UI ทันที แล้วค่อยเขียนค่าไปที่ DB
                      final next = !isOn;
                      if (mounted) {
                        setState(() {
                          isOn = next;
                        });
                      }
                      // ไม่ต้องรอ await ที่ onTap เพื่อให้ UI ลื่น
                      _updateStatus(next);
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
                    color: isOn
                        ? Colors.greenAccent.shade700
                        : const Color.fromRGBO(116, 114, 114, 1),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 15,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _busy
                        ? const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(strokeWidth: 4),
                          )
                        : const Icon(
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
                color: isOn
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
