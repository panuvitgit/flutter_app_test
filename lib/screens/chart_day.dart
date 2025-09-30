import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class ChartDay extends StatefulWidget {
  const ChartDay({super.key});

  @override
  State<ChartDay> createState() => _ChartDayState();
}

class _ChartDayState extends State<ChartDay> {
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

    // ---------- ช่วง "เมื่อวาน (Local 00:00 → 24:00)" ----------
    final now = DateTime.now();
    final DateTime targetDay = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    final DateTime startOfDay = targetDay;                          // local 00:00
    final DateTime endOfDay   = startOfDay.add(const Duration(days: 1)); // local 24:00

    // ✅ ใช้ UTC epoch (วินาที) เพื่อให้ตรงกับ key ใน RTDB
    final int startTsUtc = (startOfDay.toUtc().millisecondsSinceEpoch / 1000).floor();
    final int endTsUtc   = (endOfDay.toUtc().millisecondsSinceEpoch / 1000).floor();

    final Orientation orientation = MediaQuery.of(context).orientation;
    final String titleDate = DateFormat('yyyy-MM-dd').format(startOfDay);

    return Scaffold(
      appBar: AppBar(title: Text('Daily Report • $titleDate')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final double cardHeight = viewport.maxHeight * 0.60;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: StreamBuilder<DatabaseEvent>(
                    stream: ref
                        .orderByKey()
                        // 🔧 เผื่อ 1 วินาทีก่อนเริ่มวัน เพื่อใช้ boundary (ค่า eStart)
                        .startAt((startTsUtc - 1).toString())
                        // 🔧 end-exclusive [start, end) เพื่อลด payload และชัดเจน
                        .endAt((endTsUtc - 1).toString())
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
                            child: Text('No data for this day', style: TextStyle(color: Colors.black54)),
                          ),
                        );
                      }

                      final mapRaw = Map<dynamic, dynamic>.from(raw);

                      // ---- รายชั่วโมง: ใช้ record "ล่าสุดในชั่วโมงนั้น" ----
                      final _HourlySeries series = _hourlyLatestFromDb(
                        mapRaw,
                        startOfDay: startOfDay,
                        endOfDay: endOfDay,
                      );
                      final List<double> hourlyPower = series.powerW; // 24 จุด
                      final List<int?> tsPerHour = series.tsSec;      // ts ต่อชั่วโมง (อาจเป็น null ได้)

                      // จุดกราฟ (กำลังไฟ W)
                      final List<FlSpot> spots = List<FlSpot>.generate(
                        24,
                        (i) => FlSpot(i.toDouble(), hourlyPower[i]),
                      );

                      // สเกลแกน Y
                      final double maxVal = hourlyPower.fold<double>(0, (p, v) => math.max(p, v));
                      final double maxY = math.max(10, (maxVal * 1.2).ceilToDouble());

                      // ✅ Peak/Min จากเฉพาะชั่วโมงที่มีข้อมูลจริง
                      int? peakHour, minHour;
                      double? peakPowerW, minPowerW;
                      for (int i = 0; i < 24; i++) {
                        if (tsPerHour[i] == null) continue; // ข้ามชั่วโมงว่าง
                        final w = hourlyPower[i];
                        if (peakPowerW == null || w > peakPowerW) {
                          peakPowerW = w; peakHour = i;
                        }
                        if (minPowerW == null || w < minPowerW) {
                          minPowerW = w; minHour = i;
                        }
                      }
                      // fallback ถ้าไม่มีข้อมูลทั้งวัน
                      peakHour ??= 0;  peakPowerW ??= hourlyPower[0];
                      minHour  ??= 0;  minPowerW  ??= hourlyPower[0];

                      // -------- entries แบบเรียงเวลา (ใช้ทั้ง energy/power) --------
                      final List<MapEntry<int, Map<dynamic, dynamic>>> entries = [];
                      mapRaw.forEach((k, v) {
                        final int? ts = int.tryParse(k.toString());
                        if (ts == null) return;
                        final mv = (v is Map) ? Map<dynamic, dynamic>.from(v) : <dynamic, dynamic>{};
                        entries.add(MapEntry(ts, mv));
                      });
                      entries.sort((a, b) => a.key.compareTo(b.key));

                      // -------- 1) รวมแบบ increments ภายในวัน (มาตรฐาน) --------
                      double incrementsKWh = 0.0;
                      double? prevEnergyInDay;
                      for (final e in entries) {
                        final ts = e.key;
                        if (ts < startTsUtc || ts >= endTsUtc) continue;
                        final double? cur = _tryParseToDouble(e.value['energy']);
                        if (cur != null) {
                          if (prevEnergyInDay != null) {
                            final d = cur - prevEnergyInDay!;
                            if (d.isFinite && d > 0) incrementsKWh += d;
                          }
                          prevEnergyInDay = cur;
                        }
                      }

                      // -------- 2) โหมด boundary-difference (แม่นยำที่ขอบวัน) --------
                      double? eBeforeStart;   // ค่ามิเตอร์ล่าสุด "ก่อน" 00:00
                      double? eLastBeforeEnd; // ค่ามิเตอร์ล่าสุด "ก่อน" 24:00
                      for (final e in entries) {
                        final ts = e.key;
                        final double? val = _tryParseToDouble(e.value['energy']);
                        if (val == null) continue;
                        if (ts < startTsUtc) eBeforeStart = val;     // อัปเดตจนกว่าจะถึง start
                        if (ts < endTsUtc)   eLastBeforeEnd = val;   // อัปเดตจนสุดขอบวัน
                      }
                      double? boundaryKWh;
                      if (eBeforeStart != null && eLastBeforeEnd != null) {
                        final diff = eLastBeforeEnd! - eBeforeStart!;
                        if (diff.isFinite && diff > 0) boundaryKWh = diff;
                      }

                      // -------- 3) เลือกค่าหลัก + Fallback จาก power series --------
                      double totalEnergyKWh = boundaryKWh ?? incrementsKWh;

                      if (totalEnergyKWh == 0.0) {
                        // สร้าง power series ภายในวัน แล้วอินทิเกรตแบบทราเพโซอิด
                        final List<MapEntry<int, double>> powerPts = [];
                        for (final e in entries) {
                          final ts = e.key;
                          if (ts < startTsUtc || ts >= endTsUtc) continue;
                          final double pw = _numToDouble(e.value['power']);
                          powerPts.add(MapEntry(ts, pw));
                        }
                        totalEnergyKWh = _energyKWhFromPowerSeries(powerPts);

                        // ถ้ายังไม่มีข้อมูล power เลย ใช้รายชั่วโมงแทน (หยาบ)
                        if (totalEnergyKWh == 0.0) {
                          final sumHourlyW = hourlyPower.fold<double>(0, (s, v) => s + v);
                          totalEnergyKWh = sumHourlyW / 1000.0;
                        }
                      }

                      final double totalWh   = totalEnergyKWh * 1000.0; // Wh ทั้งวัน
                      final double avgPowerW = totalWh / 24.0;

                      final Widget chart = _buildLineChart(
                        spots,
                        maxY,
                        startOfDay,
                        tsPerHour,
                      );

                      // ------- เลื่อนแนวนอนให้เห็นทั้ง 24 ชม. และเลย 23:00 ได้ -------
                      const double tickWidth = 130.0; // ความกว้างต่อชั่วโมง
                      final double screenW = viewport.maxWidth;
                      final double chartWidthPortrait =
                          math.max(screenW, (25 * tickWidth)); // 24 ชม. + ช่องว่าง 1 ชม. ขวาสุด
                      final bool needScroll = chartWidthPortrait > screenW;

                      final Widget zoomableChart = InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 3.5,
                        boundaryMargin: const EdgeInsets.all(48),
                        clipBehavior: Clip.none,
                        child: SizedBox(
                          width: chartWidthPortrait,
                          height: cardHeight,
                          child: chart,
                        ),
                      );

                      final fmt0 = NumberFormat('#,##0');

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🔁 แสดงหน่วยให้ถูกต้อง
                          Text(
                            'Total Energy: ${totalEnergyKWh.toStringAsFixed(2)} kWh',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: cardHeight,
                            child: orientation == Orientation.portrait
                                ? (needScroll
                                    ? Scrollbar(
                                        controller: _hScroll,
                                        interactive: true,
                                        thumbVisibility: true,
                                        child: SingleChildScrollView(
                                          controller: _hScroll,
                                          scrollDirection: Axis.horizontal,
                                          child: zoomableChart,
                                        ),
                                      )
                                    : zoomableChart)
                                : zoomableChart,
                          ),
                          const SizedBox(height: 14),
                          _buildSummaryGrid(
                            totalEnergyKWh: totalEnergyKWh,
                            totalWh: totalWh,
                            avgPowerW: avgPowerW,
                            peakPowerW: peakPowerW!,
                            peakHour: peakHour!,
                            minPowerW: minPowerW!,
                            minHour: minHour!,
                            fmt0: fmt0,
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

  /// รวมข้อมูลรายชั่วโมงแบบ "ใช้ค่าล่าสุดในชั่วโมงนั้น"
  _HourlySeries _hourlyLatestFromDb(
    Map<dynamic, dynamic> raw, {
    required DateTime startOfDay, // local
    required DateTime endOfDay,   // local
  }) {
    final values = List<double>.filled(24, 0.0);
    final tsList = List<int?>.filled(24, null);

    raw.forEach((k, v) {
      final int? ts = int.tryParse(k.toString());
      if (ts == null) return;

      final dtLocal = DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true).toLocal();
      if (dtLocal.isBefore(startOfDay) || !dtLocal.isBefore(endOfDay)) return;

      final int h = dtLocal.difference(startOfDay).inHours.clamp(0, 23);
      final map = (v is Map) ? Map<dynamic, dynamic>.from(v) : <String, dynamic>{};
      final double power = _numToDouble(map['power']);

      if (tsList[h] == null || ts > tsList[h]!) {
        tsList[h] = ts;
        values[h] = power;
      }
    });

    return _HourlySeries(values, tsList);
  }

  LineChart _buildLineChart(
    List<FlSpot> spots,
    double maxY,
    DateTime startOfDay, // local
    List<int?> tsPerHour,
  ) {
    final double yStep = math.max(1, (maxY / 5).ceilToDouble());
    final dateFmt = DateFormat('yyyy-MM-dd');
    final timeFmt = DateFormat('HH:00');

    return LineChart(
      LineChartData(
        minX: 0.0,
        maxX: 24.0,
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            tooltipBorder: const BorderSide(width: 1, color: Colors.black87),
            tooltipBorderRadius: BorderRadius.circular(8),
            getTooltipItems: (touchedSpots) => touchedSpots
                .map((s) => LineTooltipItem(
                      '${s.y.toStringAsFixed(2)} W',
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
                  value.toInt().toString(),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: 1,
              getTitlesWidget: (value, _) {
                final int v = value.toInt();
                if (v < 0 || v > 23) return const SizedBox.shrink();
                final dt = startOfDay.add(Duration(hours: v));
                final bool showDate = (v == 0 || v == 23);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showDate)
                      Text(dateFmt.format(dt), style: const TextStyle(fontSize: 10, color: Colors.black87)),
                    const SizedBox(height: 2),
                    Text(timeFmt.format(dt), style: const TextStyle(fontSize: 11, color: Colors.black87)),
                  ],
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

  Widget _buildSummaryGrid({
    required double totalEnergyKWh,
    required double totalWh,
    required double avgPowerW,
    required double peakPowerW,
    required int peakHour,
    required double minPowerW,
    required int minHour,
    required NumberFormat fmt0,
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
        value: '${fmt0.format(totalWh)} Wh',
        icon: Icons.flash_on_outlined,
        color: const Color(0xFFFB8C00),
      ),
     
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
        final int cols = isPortrait ? 2 : 3;
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
  /// pts = [(tsSec, powerW)] ช่วงเวลาไม่จำเป็นต้องสม่ำเสมอ
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

class _HourlySeries {
  final List<double> powerW; // 24 ค่า
  final List<int?> tsSec;    // epoch ที่เลือกต่อชั่วโมง
  _HourlySeries(this.powerW, this.tsSec);
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.70))),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
