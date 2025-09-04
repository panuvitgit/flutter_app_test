import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ChartUtils {
  static final DatabaseReference _historyRef =
      FirebaseDatabase.instance.ref('device1/history');

  static Future<List<FlSpot>> fetchChartData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startTs = startDate.millisecondsSinceEpoch ~/ 1000;
    final endTs = endDate.millisecondsSinceEpoch ~/ 1000;

    final snapshot = await _historyRef
        .orderByKey()
        .startAt(startTs.toString())
        .endAt(endTs.toString())
        .once();

    final rawData = snapshot.snapshot.value;
    if (rawData is! Map) return [];

    List<FlSpot> spots = [];
    rawData.forEach((key, value) {
      final ts = int.tryParse(key.toString()) ?? 0;
      if (value is Map && ts >= startTs && ts <= endTs) {
        final double pwr = (value['power'] ?? 0).toDouble();
        spots.add(FlSpot(ts.toDouble(), pwr));
      }
    });

    spots.sort((a, b) => a.x.compareTo(b.x));
    return spots;
  }

  static String formatTimestamp(double ts, String mode) {
    final date = DateTime.fromMillisecondsSinceEpoch(ts.toInt() * 1000);
    switch (mode) {
      case 'day':
        return DateFormat('HH:mm').format(date);
      case 'week':
        return DateFormat('E').format(date);
      case 'month':
        return DateFormat('dd/MM').format(date);
      default:
        return DateFormat('dd/MM').format(date);
    }
  }
}
