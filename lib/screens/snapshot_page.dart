import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

// ปรับให้ตรงกับชื่อจริงใน Storage ของคุณ
// ถ้ายังเป็น current.jpg.png ให้ใช้ 'esp32/current.jpg.png'
const String kStoragePath = 'esp32/current.jpg';

class SnapshotPage extends StatefulWidget {
  const SnapshotPage({super.key});

  @override
  State<SnapshotPage> createState() => _SnapshotPageState();
}

class _SnapshotPageState extends State<SnapshotPage> {
  String? _imageUrl;
  bool _loading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadImageUrl();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _loadImageUrl()); // auto-refresh
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadImageUrl() async {
    try {
      setState(() => _loading = true);
      final ref = FirebaseStorage.instance.ref(kStoragePath);
      final rawUrl = await ref.getDownloadURL();
      final busted = '$rawUrl?ts=${DateTime.now().millisecondsSinceEpoch}';
      if (!mounted) return;
      setState(() => _imageUrl = busted);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดรูปไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Snapshot'),
        backgroundColor: const Color.fromARGB(255, 71, 66, 79),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadImageUrl),
        ],
      ),
      body: Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: _imageUrl == null
            ? (_loading
                ? const CircularProgressIndicator()
                : const Text('ยังไม่มีรูป', style: TextStyle(color: Colors.white)))
            : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _imageUrl!,
                  key: ValueKey(_imageUrl),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Text('แสดงรูปไม่ได้', style: TextStyle(color: Colors.white)),
                ),
              ),
      ),
    );
  }
}
