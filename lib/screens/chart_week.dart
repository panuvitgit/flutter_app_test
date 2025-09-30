import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class ChartWeek extends StatefulWidget {
  const ChartWeek({super.key});

  @override
  State<ChartWeek> createState() => _ChartWeekState();
}

class _ChartWeekState extends State<ChartWeek> {
  static const Color kLineColor = Color(0xFF43A5F5);
  final ScrollController _hScroll = ScrollController();

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DatabaseReference ref = FirebaseDatabase.instance.ref('/device1/history');

    // ----- ย้อนหลัง 7 วัน (สิ้นสุดที่ 00:00 วันนี้ = ไม่รวมวันนี้) -----
    final now = DateTime.now();
    final DateTime endOfWeekLocal = DateTime(now.year, now.month, now.day); // local 00:00 วันนี้ (exclusive)
    final DateTime startOfWeekLocal = endOfWeekLocal.subtract(const Duration(days: 7)); // local 00:00 ก่อน 7 วัน

    // ใช้ epoch(UTC) ในการ query (ให้เหมือนหน้า Day: startAt(start-1) .. endAt(end-1))
    final int startTsUtc = (startOfWeekLocal.toUtc().millisecondsSinceEpoch / 1000).floor();
    final int endTsUtc   = (endOfWeekLocal.toUtc().millisecondsSinceEpoch   / 1000).floor();

    final String title =
        'Weekly Report • ${DateFormat('yyyy-MM-dd').format(startOfWeekLocal)} → ${DateFormat('yyyy-MM-dd').format(endOfWeekLocal.subtract(const Duration(days: 1)))}';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final double cardHeight = viewport.maxHeight * 0.60;
            const double tickWidth = 120.0; // กว้างต่อ 1 วัน
            final double screenW = viewport.maxWidth;
            final double chartCanvasWidth = math.max(screenW * 1.2, 8 * tickWidth); // 7 วัน + ช่องว่าง

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: StreamBuilder<DatabaseEvent>(
                    stream: ref
                        .orderByKey()
                        .startAt((startTsUtc - 1).toString()) // baseline ให้เห็น s-1
                        .endAt((endTsUtc - 1).toString())     // end-exclusive [start, end)
                        .onValue,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return SizedBox(
                          height: cardHeight,
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      }

                      final dynamic raw = snapshot.data?.snapshot.value;
                      if (raw == null || raw is! Map) {
                        return SizedBox(
                          height: cardHeight,
                          child: const Center(
                            child: Text('No data in this week', style: TextStyle(color: Colors.black54)),
                          ),
                        );
                      }

                      final mapRaw = Map<dynamic, dynamic>.from(raw);

                      // ------------------------ kWh/วัน (ให้ตรงกับหน้า Day 1:1) ------------------------
                      final _DailySeries series = _dailyEnergyKWh_MatchDay(
                        mapRaw,
                        startLocal: startOfWeekLocal,
                        endLocal: endOfWeekLocal,
                      );
                      final List<double> dailyKWh = series.energyKWh; // 7 ค่า (kWh/วัน)

                      // จุดกราฟ (แกน Y เป็น kWh)
                      final List<FlSpot> spots = List<FlSpot>.generate(
                        7,
                        (i) => FlSpot(i.toDouble(), dailyKWh[i]),
                      );

                      // สเกลแกน Y
                      final double maxVal = dailyKWh.fold<double>(0, (p, v) => math.max(p, v));
                      final double maxY = (maxVal <= 0) ? 1.0 : (maxVal * 1.2);

                      // รวมพลังงานทั้งสัปดาห์ / ค่าเฉลี่ยต่อวัน
                      final double totalEnergyKWh = dailyKWh.fold<double>(0, (s, v) => s + v);
                      final double totalWh = totalEnergyKWh * 1000.0;
                      final double avgPerDayKWh   = totalEnergyKWh / 7.0;

                      // วันพีค/ต่ำสุด
                      int peakIdx = 0, minIdx = 0;
                      double peakKWh = dailyKWh[0], minKWh = dailyKWh[0];
                      for (int i = 1; i < 7; i++) {
                        if (dailyKWh[i] > peakKWh) { peakKWh = dailyKWh[i]; peakIdx = i; }
                        if (dailyKWh[i] < minKWh)  { minKWh  = dailyKWh[i];  minIdx  = i; }
                      }
                      final DateTime peakDate = startOfWeekLocal.add(Duration(days: peakIdx));
                      final DateTime minDate  = startOfWeekLocal.add(Duration(days: minIdx));

                      final Widget chart = _buildLineChartWeekly(
                        spots: spots,
                        maxY: maxY,
                        startOfWeekLocal: startOfWeekLocal,
                        tickLabelWidth: tickWidth - 20,
                      );

                      final Widget zoomPanChart = InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 3.5,
                        panEnabled: true,
                        scaleEnabled: true,
                        constrained: false,
                        boundaryMargin: const EdgeInsets.all(48),
                        clipBehavior: Clip.none,
                        child: SizedBox(width: chartCanvasWidth, height: cardHeight, child: chart),
                      );

                      final fmt0 = NumberFormat('#,##0');
                      final shortDate = DateFormat('dd/MM');

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Energy: ${totalEnergyKWh.toStringAsFixed(2)} kWh',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(height: cardHeight, child: zoomPanChart),
                          const SizedBox(height: 12),

                          // ------------------------ SUMMARY (สไตล์เดียวกับภาพหน้า Day) ------------------------
                          _buildSummaryGrid(
                            totalEnergyKWh: totalEnergyKWh,
                            totalWh: totalWh,
                            avgPerDayKWh: avgPerDayKWh,
                            peakDayLabel: '${peakKWh.toStringAsFixed(2)} kWh @ ${shortDate.format(peakDate)}',
                            // หากอยากโชว์ lowest day แทน peak ให้สลับ card ด้านล่าง
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------- Aggregations (ตรงกับ Day) ----------------
  _DailySeries _dailyEnergyKWh_MatchDay(
    Map<dynamic, dynamic> raw, {
    required DateTime startLocal, // 00:00 ของวันแรก
    required DateTime endLocal,   // 00:00 ของวันถัดไป (exclusive)
  }) {
    // entries (ช่วงสัปดาห์: [weekStart-1, weekEnd-1])
    final List<MapEntry<int, Map<dynamic, dynamic>>> entries = [];
    raw.forEach((k, v) {
      final int? ts = int.tryParse(k.toString());
      if (ts == null) return;
      final mv = (v is Map) ? Map<dynamic, dynamic>.from(v) : <dynamic, dynamic>{};
      entries.add(MapEntry(ts, mv));
    });
    entries.sort((a, b) => a.key.compareTo(b.key));

    // day windows
    final List<int> dayStartUtc = List<int>.generate(
      7, (i) => (startLocal.add(Duration(days: i)).toUtc().millisecondsSinceEpoch ~/ 1000),
    );
    final List<int> dayEndUtc = List<int>.generate(
      7, (i) => (startLocal.add(Duration(days: i + 1)).toUtc().millisecondsSinceEpoch ~/ 1000),
    );

    final List<double> dailyKWh = List<double>.filled(7, 0.0);

    for (int i = 0; i < 7; i++) {
      final int s = dayStartUtc[i];
      final int e = dayEndUtc[i];
      final int sMinus1 = s - 1;

      double? eBeforeStart;       // baseline: เฉพาะ ts == s-1
      double? eLastBeforeEnd;     // ล่าสุดใน [s-1, e)
      double? prevInDay;          // สำหรับ increments ใน [s, e)
      double sumIncrements = 0.0;
      final List<MapEntry<int, double>> powerPts = [];

      for (final it in entries) {
        final int ts = it.key;
        if (ts < sMinus1 || ts >= e) continue;

        final double? energy = _tryParseToDouble(it.value['energy']);
        final double powerW  = _numToDouble(it.value['power']);

        if (energy != null) {
          if (ts == sMinus1) eBeforeStart = energy; // baseline Day
          eLastBeforeEnd = energy;                  // ล่าสุดก่อน e (รวม s-1)

          if (ts >= s) {
            if (prevInDay != null) {
              final diff = energy - prevInDay!;
              if (diff.isFinite && diff > 0) sumIncrements += diff;
            }
            prevInDay = energy;
          }
        }

        if (ts >= s) powerPts.add(MapEntry(ts, powerW));
      }

      double? boundary;
      if (eBeforeStart != null && eLastBeforeEnd != null) {
        final diff = eLastBeforeEnd! - eBeforeStart!;
        if (diff.isFinite && diff > 0) boundary = diff;
      }

      double kwh;
      if (boundary != null) {
        kwh = boundary;
      } else if (sumIncrements > 0) {
        kwh = sumIncrements;
      } else {
        kwh = _energyKWhFromPowerSeries(powerPts);
      }

      dailyKWh[i] = kwh;
    }

    return _DailySeries(dailyKWh);
  }

  // ---------------- Chart ----------------
  LineChart _buildLineChartWeekly({
    required List<FlSpot> spots,
    required double maxY,
    required DateTime startOfWeekLocal,
    required double tickLabelWidth,
  }) {
    final double yStep = (maxY <= 1.0) ? math.max(0.1, maxY / 5) : (maxY / 5);

    final dateShort = DateFormat('dd/MM');
    final weekdayFmt = DateFormat('EEE');

    return LineChart(
      LineChartData(
        minX: 0.0,
        maxX: 7.0,
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            tooltipBorder: const BorderSide(width: 1, color: Colors.black87),
            tooltipBorderRadius: BorderRadius.circular(8),
            getTooltipItems: (touched) => touched
                .map((s) => LineTooltipItem(
                      '${s.y.toStringAsFixed(2)} kWh',
                      const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ))
                .toList(),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: yStep,
          verticalInterval: 1,
          getDrawingHorizontalLine: (v) => FlLine(color: Colors.black12.withOpacity(0.2), strokeWidth: 1),
          getDrawingVerticalLine: (v) => FlLine(color: Colors.black12.withOpacity(0.2), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              interval: yStep,
              getTitlesWidget: (value, _) => SizedBox(
                width: 52,
                child: Text(
                  (maxY < 10 ? value.toStringAsFixed(1) : value.toStringAsFixed(0)),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              interval: 1,
              getTitlesWidget: (value, _) {
                final int v = value.toInt();
                if (v < 0 || v > 6) return const SizedBox.shrink();
                final dt = startOfWeekLocal.add(Duration(days: v));

                return SizedBox(
                  width: tickLabelWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dateShort.format(dt),
                        style: const TextStyle(fontSize: 10, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        softWrap: false,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        weekdayFmt.format(dt),
                        style: const TextStyle(fontSize: 11, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        softWrap: false,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.black26.withOpacity(0.4)),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: false,
            color: kLineColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            spots: spots,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [kLineColor.withOpacity(0.12), kLineColor.withOpacity(0.02), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        clipData: const FlClipData(left: true, top: true, right: false, bottom: true),
      ),
      duration: const Duration(milliseconds: 350),
    );
  }

  // ---------------- Summary (สไตล์เดียวกับภาพหน้า Day) ----------------
  Widget _buildSummaryGrid({
    required double totalEnergyKWh,
    required double totalWh,
    required double avgPerDayKWh,
    required String peakDayLabel, // e.g. "0.93 kWh @ 08/09"
  }) {
    final items = <_SummaryItem>[
      _SummaryItem(
        title: 'Total Energy',
        value: '${totalEnergyKWh.toStringAsFixed(2)} kWh',
        icon: Icons.battery_full_outlined,
        color: const Color(0xFF2E7D32),
      ),
      _SummaryItem(
        title: 'Total (Wh)',
        value: '${NumberFormat('#,##0').format(totalWh)} Wh',
        icon: Icons.flash_on_outlined,
        color: const Color(0xFFFB8C00),
      ),
      
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
        final int cols = isPortrait ? 2 : 4; // แนวนอนวาง 4 ใบในแถวเดียว
        const double spacing = 12.0;
        final double tileWidth = (constraints.maxWidth - (cols - 1) * spacing) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map((e) => SizedBox(
                    width: tileWidth,
                    child: _SummaryCard(
                      title: e.title,
                      value: e.value,
                      icon: e.icon,
                      color: e.color,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  // ---------- Helpers ----------
  double _numToDouble(dynamic x) {
    if (x is num) return x.toDouble();
    if (x is String) return double.tryParse(x) ?? 0.0;
    return 0.0;
  }

  double? _tryParseToDouble(dynamic x) {
    if (x is num) return x.toDouble();
    if (x is String) return double.tryParse(x);
    return null;
  }

  /// อินทิเกรตพลังงานจาก power series แบบทราเพโซอิด (ผลลัพธ์เป็น kWh)
  double _energyKWhFromPowerSeries(List<MapEntry<int, double>> pts) {
    if (pts.length < 2) return 0.0;
    pts.sort((a, b) => a.key.compareTo(b.key));
    double wh = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final dtHour = (pts[i].key - pts[i - 1].key) / 3600.0; // ชั่วโมง
      if (dtHour <= 0) continue;
      final pAvg = 0.5 * (pts[i].value + pts[i - 1].value);  // W เฉลี่ยช่วง
      wh += pAvg * dtHour;                                   // Wh
    }
    return wh / 1000.0; // -> kWh
  }
}

// ---------------- Models ----------------
class _DailySeries {
  final List<double> energyKWh; // length 7, kWh/วัน
  _DailySeries(this.energyKWh);
}

class _SummaryItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _SummaryItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

// ---------------- Summary Card (สไตล์เดียวกับหน้า Day) ----------------
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.65)),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
