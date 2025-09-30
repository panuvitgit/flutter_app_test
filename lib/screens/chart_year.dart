import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

const Color kLineColor = Color(0xFF43A5F5);

// ถ้า field `energy` ในฐานข้อมูลเป็น Wh ให้ตั้ง = 0.001 (ค่าเริ่มต้น = kWh)
const double kEnergyUnitFactor = 1.0;

class ChartYear extends StatefulWidget {
  const ChartYear({super.key});

  @override
  State<ChartYear> createState() => _ChartYearState();
}

class _ChartYearState extends State<ChartYear> {
  @override
  Widget build(BuildContext context) {
    final DatabaseReference ref = FirebaseDatabase.instance.ref('/device1/history');

    final now = DateTime.now();
    final int year = now.year;

    // ช่วงแสดงผล: 12 เดือนเต็มของปีนี้
    final DateTime displayStart = DateTime(year, 1, 1);
    final DateTime displayEnd   = DateTime(year + 1, 1, 1); // exclusive

    // ช่วงคำนวณจริง: ถึงต้นเดือนถัดไปของเดือนปัจจุบัน (ไม่รวมอนาคต)
    final DateTime statsEnd = DateTime(now.year, now.month + 1, 1);
    final DateTime queryEnd = statsEnd.isBefore(displayEnd) ? statsEnd : displayEnd;

    // ใช้สตาร์ตที่ (Jan 1 - 1s) เพื่อมี baseline ของเดือนม.ค. ถ้ามีใน DB
    final int queryStartUtc = (displayStart.toUtc().millisecondsSinceEpoch ~/ 1000) - 1;
    final int queryEndUtc   =  (queryEnd.toUtc().millisecondsSinceEpoch   ~/ 1000) - 1; // end-exclusive

    return Scaffold(
      appBar: AppBar(title: Text('Yearly Report • $year')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final double cardHeight = viewport.maxHeight * 0.64;

            // ให้ผืนกราฟกว้างเกินจอเล็กน้อยเพื่อแพนได้แม้ยังไม่ซูม
            const double tickWidth = 92.0;
            final double screenW = viewport.maxWidth;
            final double canvasW = math.max(screenW * 1.2, (12 + 1) * tickWidth);

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
                        .startAt(queryStartUtc.toString()) // include baseline (Jan-1 sec)
                        .endAt(queryEndUtc.toString())     // [start, end)
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
                            child: Text('No data this year', style: TextStyle(color: Colors.black54)),
                          ),
                        );
                      }
                      final mapRaw = Map<dynamic, dynamic>.from(raw);

                      // ---------- คำนวณพลังงานรวมต่อเดือน (kWh/เดือน) 12 จุด ----------
                      final List<double> monthlyKWh = _monthlyEnergyKWhMatchDay(
                        mapRaw,
                        year: year,
                      );

                      // จุดกราฟ (แกน Y เป็น kWh/เดือน)
                      final List<FlSpot> spots = List<FlSpot>.generate(
                        12,
                        (i) => FlSpot(i.toDouble(), monthlyKWh[i]),
                      );

                      // สเกลแกน Y
                      final double maxVal = monthlyKWh.fold<double>(0, (p, v) => math.max(p, v));
                      final double maxY = (maxVal <= 0) ? 1.0 : (maxVal * 1.2);

                      // รวมทั้งปี และค่าเฉลี่ยรายเดือน
                      final double totalEnergyKWh = monthlyKWh.fold<double>(0, (s, v) => s + v);
                      final double totalWh        = totalEnergyKWh * 1000.0;
                      final double avgPerMonthKWh = totalEnergyKWh / 12.0;

                      // หาเดือนพีค/ต่ำสุด
                      int peakIdx = 0, minIdx = 0;
                      double peakVal = monthlyKWh[0], minVal = monthlyKWh[0];
                      for (int i = 1; i < 12; i++) {
                        if (monthlyKWh[i] > peakVal) { peakVal = monthlyKWh[i]; peakIdx = i; }
                        if (monthlyKWh[i] < minVal)  { minVal  = monthlyKWh[i];  minIdx  = i; }
                      }
                      final DateTime peakMonth = DateTime(year, peakIdx + 1, 1);

                      // วาดกราฟ
                      final Widget chart = _buildLineChartYearKWh(
                        spots: spots,
                        maxY: maxY,
                        yearStart: displayStart,
                        tickLabelWidth: tickWidth - 14,
                      );

                      // ซูม/แพนด้วยนิ้วเดียว
                      final Widget zoomPanChart = InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 3.5,
                        panEnabled: true,
                        scaleEnabled: true,
                        constrained: false,
                        boundaryMargin: const EdgeInsets.all(48),
                        clipBehavior: Clip.none,
                        child: SizedBox(width: canvasW, height: cardHeight, child: chart),
                      );

                      final dateFmt = DateFormat('MMM');

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Energy: ${_fmtEnergy(totalEnergyKWh)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(height: cardHeight, child: zoomPanChart),
                          const SizedBox(height: 12),
                          _buildSummaryGrid(
                            totalEnergyKWh: totalEnergyKWh,
                            totalWh: totalWh,
                            avgPerMonthKWh: avgPerMonthKWh,
                            peakLabel: '${peakVal.toStringAsFixed(2)} kWh @ ${dateFmt.format(peakMonth)}',
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

  // ---------------- Aggregations (ให้ตรงกติกาหน้า Day) ----------------

  /// รวมพลังงานต่อเดือนแบบเดียวกับ Day: boundary(s-1) → positive increments → power trapezoid
  List<double> _monthlyEnergyKWhMatchDay(
    Map<dynamic, dynamic> raw, {
    required int year,
  }) {
    // entries ทั้งช่วง (เรียงเวลา)
    final List<MapEntry<int, Map<dynamic, dynamic>>> entries = [];
    raw.forEach((k, v) {
      final int? ts = int.tryParse(k.toString());
      if (ts == null) return;
      final mv = (v is Map) ? Map<dynamic, dynamic>.from(v) : <dynamic, dynamic>{};
      entries.add(MapEntry(ts, mv));
    });
    entries.sort((a, b) => a.key.compareTo(b.key));

    final List<double> monthlyKWh = List<double>.filled(12, 0.0);

    for (int m = 1; m <= 12; m++) {
      final DateTime sLocal = DateTime(year, m, 1);
      final DateTime eLocal = DateTime(year, m + 1, 1);
      final int s = sLocal.toUtc().millisecondsSinceEpoch ~/ 1000;
      final int e = eLocal.toUtc().millisecondsSinceEpoch ~/ 1000;
      final int sMinus1 = s - 1;

      double? eBeforeStart;   // energy @ s-1 (baseline)
      double? eLastBeforeEnd; // energy ล่าสุดในช่วง [s-1, e)
      double? prevInRange;    // สำหรับ increments ภายใน [s, e)
      double sumIncrements = 0.0;
      final List<MapEntry<int, double>> powerPts = [];

      for (final it in entries) {
        final int ts = it.key;
        if (ts < sMinus1 || ts >= e) continue; // พิจารณาเฉพาะ [s-1, e)

        final double? energy = _tryParseToDouble(it.value['energy']);
        final double powerW  = _numToDouble(it.value['power']);

        if (energy != null) {
          if (ts == sMinus1) eBeforeStart = energy; // baseline ตามหน้า Day
          eLastBeforeEnd = energy;                  // อัปเดตล่าสุดจนก่อน e

          if (ts >= s) {
            if (prevInRange != null) {
              final diff = energy - prevInRange!;
              if (diff.isFinite && diff > 0) sumIncrements += diff * kEnergyUnitFactor;
            }
            prevInRange = energy;
          }
        }

        if (ts >= s) powerPts.add(MapEntry(ts, powerW));
      }

      double? boundary;
      if (eBeforeStart != null && eLastBeforeEnd != null) {
        final diff = (eLastBeforeEnd! - eBeforeStart!) * kEnergyUnitFactor;
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

      monthlyKWh[m - 1] = kwh;
    }

    return monthlyKWh;
  }

  // อินทิเกรตพลังงานจาก power series (ผลลัพธ์เป็น kWh)
  double _energyKWhFromPowerSeries(List<MapEntry<int, double>> pts) {
    if (pts.length < 2) return 0.0;
    pts.sort((a, b) => a.key.compareTo(b.key));
    double wh = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final double dtHour = (pts[i].key - pts[i - 1].key) / 3600.0;
      if (dtHour <= 0) continue;
      final double pAvg = 0.5 * (pts[i].value + pts[i - 1].value);
      wh += pAvg * dtHour;
    }
    return wh / 1000.0;
  }

  // ---------------- Chart (แกน Y = kWh/เดือน) ----------------
  LineChart _buildLineChartYearKWh({
    required List<FlSpot> spots,
    required double maxY,
    required DateTime yearStart,
    required double tickLabelWidth,
  }) {
    final double yStep = (maxY <= 1.0) ? math.max(0.1, maxY / 5) : (maxY / 5);
    final dateTopFmt = DateFormat('yyyy'); // โชว์บน Jan/Dec
    final dateBotFmt = DateFormat('MMM');  // ชื่อเดือน
    return LineChart(
      LineChartData(
        minX: 0.0,
        maxX: 12.0,
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
                if (v < 0 || v > 11) return const SizedBox.shrink();
                final dt = DateTime(yearStart.year, v + 1, 1);
                final bool major = (v == 0 || v == 11);
                return SizedBox(
                  width: tickLabelWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (major)
                        Text(
                          dateTopFmt.format(dt),
                          style: const TextStyle(fontSize: 10, color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          softWrap: false,
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 2),
                      Text(
                        dateBotFmt.format(dt),
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

  // ---------------- Summary (เหมือนกราฟก่อนหน้า) ----------------
  Widget _buildSummaryGrid({
    required double totalEnergyKWh,
    required double totalWh,
    required double avgPerMonthKWh,
    required String peakLabel, // "X.XX kWh @ MMM"
  }) {
    final items = <_SummaryItem>[
      _SummaryItem(
        title: 'Total Energy',
        value: _fmtEnergy(totalEnergyKWh),
        icon: Icons.battery_full_outlined,
        color: const Color(0xFF2E7D32),
      ),
      _SummaryItem(
        title: 'Total (Wh)',
        value: _fmtWh(totalWh),
        icon: Icons.flash_on_outlined,
        color: const Color(0xFFFB8C00),
      ),
     
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
        final int cols = isPortrait ? 2 : 4;
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

  // ---------------- Formatting helpers ----------------
  static String _fmtEnergy(double kWh) {
    if (kWh.abs() >= 100000) return '${NumberFormat.compact().format(kWh)} kWh';
    return '${kWh.toStringAsFixed(2)} kWh';
  }

  static String _fmtWh(double wh) {
    if (wh.abs() >= 1e6) return '${(wh / 1e6).toStringAsFixed(2)} MWh';
    if (wh.abs() >= 1e3) return '${(wh / 1e3).toStringAsFixed(2)} kWh';
    return '${wh.toStringAsFixed(0)} Wh';
  }

  // ---------- Small helpers ----------
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
}

// ---------------- Models & UI ----------------
class _SummaryItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  _SummaryItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
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
                Text(title, style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.65))),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color, height: 1.1),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.65)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
