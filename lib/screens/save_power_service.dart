
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

class PowerSaverService {
  static final DatabaseReference _historyRef =
      FirebaseDatabase.instance.ref('device1/history');

  Timer? _timer;

  void startSavingEvery12Hours() {
    // เริ่มบันทึกทุก 12 ชั่วโมง (43200 วินาที)
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(hours: 12), (_) async {
      await _saveOnce();
    });

    // บันทึกทันทีครั้งแรก (เพื่อไม่ต้องรอ 12 ชั่วโมง)
    _saveOnce();
  }

  Future<void> _saveOnce() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // TODO: ดึงค่าจาก sensor หรือจาก realtime database ปัจจุบัน
      double voltage = 230.0;
      double current = 0.45;
      double power = voltage * current;
      double energy = 1.2; // kWh (คุณต้องคำนวณจริงตามสูตรของคุณ)

      await _historyRef.child(timestamp.toString()).set({
        "timestamp": timestamp,
        "voltage": voltage,
        "current": current,
        "power": power,
        "energy": energy,
      });

      print("✅ บันทึกข้อมูลเรียบร้อย: $timestamp");
    } catch (e) {
      print("❌ บันทึกข้อมูลล้มเหลว: $e");
    }
  }

  void stop() {
    _timer?.cancel();
  }
}
