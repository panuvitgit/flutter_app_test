import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('device1');

  double voltage = 0.0;
  double current = 0.0;
  double power = 0.0;
  double energy = 0.0;

  @override
  void initState() {
    super.initState();
    _listenToFirebase();
  }

  void _listenToFirebase() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        setState(() {
          voltage = (data['voltage'] ?? 0).toDouble();
          current = (data['current'] ?? 0).toDouble();
          power = (data['power'] ?? 0).toDouble();
          energy = (data['energy'] ?? 0).toDouble();
        });
      }
    });
  }

  Widget _buildCard(String label, String unit, double value, Color color, IconData icon) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9FB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 26, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '${value.toStringAsFixed(2)} $unit',
                    style: TextStyle(fontSize: 20, color: color, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- New: Responsive grid navigation ----
  Widget _buildNavGrid(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // คอลัมน์ตามความกว้าง: แคบ=1, กลาง=2, กว้าง=3
    final int cols = width < 360 ? 1 : (width < 600 ? 2 : 3);

    final items = <_NavItem>[
      _NavItem(
        title: 'รายวัน',
        route: '/chart_day',
        icon: Icons.calendar_today,
        gradient: const [Color(0xFF43A5F5), Color(0xFF6EC6FF)],
      ),
      _NavItem(
        title: 'รายสัปดาห์',
        route: '/chart_week',
        icon: Icons.view_week,
        gradient: const [Color(0xFF7E57C2), Color(0xFFB39DDB)],
      ),
      _NavItem(
        title: 'รายเดือน',
        route: '/chart_month',
        icon: Icons.calendar_month,
        gradient: const [Color(0xFF26A69A), Color(0xFF80CBC4)],
      ),
    ];

    return GridView.count(
      crossAxisCount: cols,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // ปรับอัตราส่วนเพื่อให้ปุ่มดูสมส่วน (กว้างกว่ากึ่งหนึ่งของสูงเล็กน้อย)
      childAspectRatio: cols == 1 ? 3.6 : (cols == 2 ? 3.0 : 2.6),
      children: items.map((e) => _NavTile(item: e)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.deepPurple,
        elevation: 2,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildCard('แรงดันไฟฟ้า (Voltage)', 'V', voltage, Colors.orange, Icons.flash_on),
              _buildCard('กระแสไฟฟ้า (Current)', 'A', current, Colors.blue, Icons.bolt),
              _buildCard('กำลังไฟฟ้า (Power)', 'W', power, Colors.purple, Icons.power),
              _buildCard('พลังงานสะสม (Energy)', 'kWh', energy, Colors.green, Icons.battery_charging_full),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ดูกราฟการใช้ไฟฟ้า',
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.75),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildNavGrid(context),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Models & Widgets for nav tiles ----

class _NavItem {
  final String title;
  final String route;
  final IconData icon;
  final List<Color> gradient;

  _NavItem({
    required this.title,
    required this.route,
    required this.icon,
    required this.gradient,
  });
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  const _NavTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, item.route),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: item.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: item.gradient.last.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
