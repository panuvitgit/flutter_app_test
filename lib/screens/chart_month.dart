import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class ChartMonth extends StatefulWidget {
  const ChartMonth({super.key});

  @override
  State<ChartMonth> createState() => _ChartMonthState();
}

class _ChartMonthState extends State<ChartMonth> {
  static const Color kLineColor = Color(0xFF43A5F5);
  final ScrollController _hScroll = ScrollController();

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DatabaseReference ref =
        FirebaseDatabase.instance.ref('/device1/history');

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1);
    final int daysInMonth = endOfMonth.difference(startOfMonth).inDays;

    final int startTs = (startOfMonth.millisecondsSinceEpoch / 1000).floor();
    final int endTs = (endOfMonth.millisecondsSinceEpoch / 1000).floor();

    final Orientation orientation = MediaQuery.of(context).orientation;

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Report')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final double cardHeight = viewport.maxHeight * 0.42;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: StreamBuilder<DatabaseEvent>(
                    stream: ref
                        .orderByKey()
                        .startAt(startTs.toString())
                        .endAt(endTs.toString())
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
                            child: Text(
                              'No data this month',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        );
                      }

                      final mapRaw = Map<dynamic, dynamic>.from(raw);

                      // Daily averages for the month (N points)
                      final dailyAvg = _dailyAverageFrom(
                        mapRaw,
                        startOfMonth: startOfMonth,
                        endOfMonth: endOfMonth,
                        daysInMonth: daysInMonth,
                      );

                      // Spots & bounds
                      final List<FlSpot> spots = List<FlSpot>.generate(
                        daysInMonth,
                        (i) => FlSpot(i.toDouble(), dailyAvg[i]),
                      );

                      final double maxVal =
                          dailyAvg.fold<double>(0, (p, v) => math.max(p, v));
                      final double maxY =
                          math.max(10, (maxVal * 1.2).ceilToDouble());

                      // Monthly energy (prefer positive increments of 'energy')
                      final double totalEnergyKWh = _safeMonthlyEnergyKWh(
                        mapRaw,
                        startTs: startTs,
                        endTs: endTs,
                        fallbackAvgWPerDay: dailyAvg,
                      );

                      // Standardized monthly totals derived from energy
                      final double totalPowerW = totalEnergyKWh * 1000.0; // total Wh over month
                      final double avgPowerW =
                          daysInMonth > 0 ? totalPowerW / (daysInMonth * 24.0) : 0.0;

                      // Peak/Min based on dailyAvg
                      int peakIdx = 0;
                      double peakPowerW = dailyAvg[0];
                      int minIdx = 0;
                      double minPowerW = dailyAvg[0];
                      for (int i = 1; i < daysInMonth; i++) {
                        if (dailyAvg[i] > peakPowerW) {
                          peakPowerW = dailyAvg[i];
                          peakIdx = i;
                        }
                        if (dailyAvg[i] < minPowerW) {
                          minPowerW = dailyAvg[i];
                          minIdx = i;
                        }
                      }

                      final Widget chart =
                          _buildLineChart(spots, maxY, startOfMonth, daysInMonth);

                      // Portrait: horizontal scroll to avoid label overlap
                      // วัน/เดือนมีได้สูงสุด ~31 จุด -> เพิ่ม tickWidth ให้พอ
                      const double tickWidth = 56.0;
                      final double screenW = viewport.maxWidth;
                      final double chartWidthPortrait =
                          math.max(screenW, daysInMonth * tickWidth);
                      final bool needScroll = chartWidthPortrait > screenW;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // แสดง Total Energy ที่ด้านบนให้ชัดเจน (มาตรฐาน)
                          Text(
                            'Total Energy: ${totalEnergyKWh.toStringAsFixed(2)} kWh',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
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
                                          child: SizedBox(
                                            width: chartWidthPortrait,
                                            child: AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 350),
                                              child: KeyedSubtree(
                                                key: ValueKey('${maxY}_${spots.length}'),
                                                child: chart,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 350),
                                        child: KeyedSubtree(
                                          key: ValueKey('${maxY}_${spots.length}'),
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: chart,
                                          ),
                                        ),
                                      ))
                                : AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 350),
                                    child: KeyedSubtree(
                                      key: ValueKey('${maxY}_${spots.length}'),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: chart,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          _buildSummaryGrid(
                            totalEnergyKWh: totalEnergyKWh,
                            totalPowerW: totalPowerW,
                            avgPowerW: avgPowerW,
                            peakPowerW: peakPowerW,
                            peakDate: startOfMonth.add(Duration(days: peakIdx)),
                            minPowerW: minPowerW,
                            minDate: startOfMonth.add(Duration(days: minIdx)),
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

  /// Aggregate average power for each day in the month (N=daysInMonth points).
  List<double> _dailyAverageFrom(
    Map<dynamic, dynamic> raw, {
    required DateTime startOfMonth,
    required DateTime endOfMonth,
    required int daysInMonth,
  }) {
    final sums = List<double>.filled(daysInMonth, 0.0);
    final counts = List<int>.filled(daysInMonth, 0);

    raw.forEach((k, v) {
      final int? ts = int.tryParse(k.toString());
      if (ts == null) return;

      final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: false);
      if (dt.isBefore(startOfMonth) || !dt.isBefore(endOfMonth)) return;

      final int idx = dt.difference(startOfMonth).inDays;
      if (idx < 0 || idx >= daysInMonth) return;

      final map = (v is Map) ? Map<dynamic, dynamic>.from(v) : <String, dynamic>{};
      final num p = (map['power'] ?? 0);
      final double power = p.toDouble();

      sums[idx] += power;
      counts[idx] += 1;
    });

    return List<double>.generate(
      daysInMonth,
      (i) => counts[i] > 0 ? sums[i] / counts[i] : 0.0,
    );
  }

  LineChart _buildLineChart(
    List<FlSpot> spots,
    double maxY,
    DateTime startOfMonth,
    int daysInMonth,
  ) {
    final double yStep = math.max(1, (maxY / 5).ceilToDouble());
    final dateFmtTop = DateFormat('yyyy-MM');
    final dateFmtBottom = DateFormat('dd');

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (daysInMonth - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            // ป้องกัน tooltip ล้นกราฟ
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              final int d = spot.x.toInt().clamp(0, daysInMonth - 1);
              final dt = startOfMonth.add(Duration(days: d));
              return LineTooltipItem(
                '${DateFormat('dd MMM').format(dt)} — ${spot.y.toStringAsFixed(2)} W',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            }).toList(),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: yStep,
          verticalInterval: 1,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: Colors.black12.withOpacity(0.2), strokeWidth: 1),
          getDrawingVerticalLine: (v) =>
              FlLine(color: Colors.black12.withOpacity(0.2), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: yStep,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 11),
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
                if (v < 0 || v >= daysInMonth) return const SizedBox.shrink();
                final dt = startOfMonth.add(Duration(days: v));
                final int day = v + 1;

                // โชว์บรรทัดบน (yyyy-MM) เฉพาะบางวันเพื่อกันแน่น: 1, 10, 20, วันสุดท้าย
                final bool major =
                    (day == 1 || day == 10 || day == 20 || day == daysInMonth);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (major)
                      Text(
                        dateFmtTop.format(dt),
                        style: const TextStyle(fontSize: 10, color: Colors.black87),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      dateFmtBottom.format(dt), // dd
                      style: const TextStyle(fontSize: 11, color: Colors.black87),
                    ),
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
                colors: [
                  kLineColor.withOpacity(0.12),
                  kLineColor.withOpacity(0.02),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        clipData: const FlClipData.all(),
      ),
      duration: const Duration(milliseconds: 350),
    );
  }

  double _safeMonthlyEnergyKWh(
    Map<dynamic, dynamic> raw, {
    required int startTs,
    required int endTs,
    required List<double> fallbackAvgWPerDay,
  }) {
    final entries = <MapEntry<int, double>>[];

    raw.forEach((k, v) {
      final int? ts = int.tryParse(k.toString());
      if (ts == null) return;
      if (ts < startTs || ts >= endTs) return;
      if (v is! Map) return;
      final mv = Map<dynamic, dynamic>.from(v);
      final num? en = mv['energy'];
      if (en == null) return;
      final double e = en.toDouble();
      if (!e.isFinite) return;
      entries.add(MapEntry(ts, e));
    });

    entries.sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) {
      // fallback: sum of daily average W * 24h / 1000
      final double sumAvg = fallbackAvgWPerDay.fold(0.0, (s, v) => s + v);
      return (sumAvg * 24.0 / 1000.0).clamp(0.0, 1e12);
    }

    double totalKWh = 0.0;
    for (int i = 1; i < entries.length; i++) {
      final diff = entries[i].value - entries[i - 1].value;
      if (diff.isFinite && diff > 0) {
        totalKWh += diff;
      }
    }
    if (totalKWh <= 0) {
      final double sumAvg = fallbackAvgWPerDay.fold(0.0, (s, v) => s + v);
      totalKWh = sumAvg * 24.0 / 1000.0;
    }
    return totalKWh;
  }

  Widget _buildSummaryGrid({
    required double totalEnergyKWh,
    required double totalPowerW,
    required double avgPowerW,
    required double peakPowerW,
    required DateTime peakDate,
    required double minPowerW,
    required DateTime minDate,
  }) {
    final dateFmt = DateFormat('yyyy-MM-dd');

    final items = <_SummaryItem>[
      _SummaryItem(
        title: 'Total Energy',
        value: '${totalEnergyKWh.toStringAsFixed(2)} kWh',
        icon: Icons.battery_full_outlined,
        color: const Color(0xFF2E7D32),
      ),
      _SummaryItem(
        title: 'Total (Wh)',
        value: '${totalPowerW.toStringAsFixed(0)} Wh',
        icon: Icons.flash_on_outlined,
        color: const Color(0xFFFB8C00),
      ),
      _SummaryItem(
        title: 'Average Power',
        value: '${avgPowerW.toStringAsFixed(2)} W',
        icon: Icons.show_chart_outlined,
        color: const Color(0xFF3949AB),
      ),
      _SummaryItem(
        title: 'Peak',
        value: '${peakPowerW.toStringAsFixed(2)} W @ ${dateFmt.format(peakDate)}',
        icon: Icons.trending_up,
        color: const Color(0xFFD32F2F),
      ),
      _SummaryItem(
        title: 'Min',
        value: '${minPowerW.toStringAsFixed(2)} W @ ${dateFmt.format(minDate)}',
        icon: Icons.trending_down,
        color: const Color(0xFF00838F),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isPortrait =
            MediaQuery.of(context).orientation == Orientation.portrait;
        final int cols = isPortrait ? 2 : 3;
        const double spacing = 12.0;
        final double tileWidth =
            (constraints.maxWidth - (cols - 1) * spacing) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (e) => SizedBox(
                  width: tileWidth,
                  child: _SummaryCard(
                    title: e.title,
                    value: e.value,
                    icon: e.icon,
                    color: e.color,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
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
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.70),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
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
