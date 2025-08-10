import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('device1');
  final DatabaseReference _historyRef = FirebaseDatabase.instance.ref('device1/history',);

  double voltage = 0.0;
  double current = 0.0;
  double power = 0.0;
  double energy = 0.0;

  List<FlSpot> dailySpots = [];
  List<FlSpot> weeklySpots = [];
  List<FlSpot> monthlySpots = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _listenToFirebase();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchChartData();
    });
  }

  void _listenToFirebase() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          voltage = (data['voltage'] ?? 0).toDouble();
          current = (data['current'] ?? 0).toDouble();
          power = (data['power'] ?? 0).toDouble();
          energy = (data['energy'] ?? 0).toDouble();
        });
      }
    });
  }

  void _fetchChartData() async {
    try {
      final snapshot = await _historyRef.orderByKey().limitToLast(500).once();
      final rawData = snapshot.snapshot.value as Map?;

      if (rawData == null) return;

      List<MapEntry<int, dynamic>> entries =
          rawData.entries
              .map((e) => MapEntry(int.parse(e.key.toString()), e.value))
              .toList();

      entries.sort((a, b) => a.key.compareTo(b.key));

      final now = DateTime.now();
      final startOfToday =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/ 1000;
      final startOfWeek = startOfToday - 86400 * 6;
      final startOfMonth =
          DateTime(now.year, now.month, 1).millisecondsSinceEpoch ~/ 1000;

      List<FlSpot> day = [], week = [], month = [];

      for (final entry in entries) {
        final timestamp = entry.key;
        final data = entry.value;
        final double power = (data['power'] ?? 0).toDouble();

        if (timestamp >= startOfToday) {
          day.add(FlSpot(((timestamp - startOfToday) / 3600), power));
        }
        if (timestamp >= startOfWeek) {
          week.add(FlSpot(((timestamp - startOfWeek) / 86400), power));
        }
        if (timestamp >= startOfMonth) {
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
          month.add(FlSpot(date.day.toDouble(), power));
        }
      }

      setState(() {
        dailySpots = day;
        weeklySpots = week;
        monthlySpots = month;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching chart data: $e");
      setState(() => isLoading = false);
    }
  }

  Widget _buildChart(String title, List<FlSpot> spots, String intervalLabel) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        height: 220,
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child:
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : spots.isEmpty
                      ? const Center(child: Text('ไม่มีข้อมูล'))
                      : LineChart(
                        LineChartData(
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                interval: 1,
                                getTitlesWidget:
                                    (value, meta) => Text(
                                      '${value.toInt()}$intervalLabel',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 50,
                              ),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: true),
                          gridData: FlGridData(show: true),
                          lineBarsData: [
                            LineChartBarData(
                              isCurved: false,
                              spots: spots,
                              dotData: FlDotData(show: false),
                              color: Colors.deepPurple,
                              barWidth: 2,
                            ),
                          ],
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    String label,
    String unit,
    double value,
    Color color,
    IconData icon,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color.fromARGB(255, 251, 251, 251),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${value.toStringAsFixed(2)} $unit',
                    style: TextStyle(
                      fontSize: 20,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildCard(
              'แรงดันไฟฟ้า (Voltage)',
              'V',
              voltage,
              Colors.orange,
              Icons.flash_on,
            ),
            _buildCard(
              'กระแสไฟฟ้า (Current)',
              'A',
              current,
              Colors.blue,
              Icons.bolt,
            ),
            _buildCard(
              'กำลังไฟฟ้า (Power)',
              'W',
              power,
              Colors.purple,
              Icons.power,
            ),
            _buildCard(
              'พลังงานสะสม (Energy)',
              'kWh',
              energy,
              Colors.green,
              Icons.battery_charging_full,
            ),
            const SizedBox(height: 16),
            _buildChart('กราฟรายวัน', dailySpots, 'h'),
            _buildChart('กราฟรายสัปดาห์', weeklySpots, 'd'),
            _buildChart('กราฟรายเดือน', monthlySpots, 'd'),
          ],
        ),
      ),
    );
  }
}
