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
    final DatabaseReference ref =
        FirebaseDatabase.instance.ref('/device1/history');

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final startTs = (startOfDay.millisecondsSinceEpoch / 1000).floor();
    final endTs = (endOfDay.millisecondsSinceEpoch / 1000).floor();

    final Orientation orientation = MediaQuery.of(context).orientation;

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Report')),
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
                              'No data today',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        );
                      }

                      final mapRaw = Map<dynamic, dynamic>.from(raw);

                      // Hourly averages
                      final hourlyAvg = _hourlyAverageFrom(
                        mapRaw,
                        startOfDay: startOfDay,
                        endOfDay: endOfDay,
                      );

                      // Spots & bounds
                      final List<FlSpot> spots = List<FlSpot>.generate(
                        24,
                        (i) => FlSpot(i.toDouble(), hourlyAvg[i]),
                      );

                      final double maxVal =
                          hourlyAvg.fold<double>(0, (p, v) => math.max(p, v));
                      final double maxY =
                          math.max(10, (maxVal * 1.2).ceilToDouble());

                      // Peak/Min on hourly average
                      int peakHour = 0;
                      double peakPowerW = hourlyAvg[0];
                      int minHour = 0;
                      double minPowerW = hourlyAvg[0];
                      for (int i = 1; i < 24; i++) {
                        if (hourlyAvg[i] > peakPowerW) {
                          peakPowerW = hourlyAvg[i];
                          peakHour = i;
                        }
                        if (hourlyAvg[i] < minPowerW) {
                          minPowerW = hourlyAvg[i];
                          minHour = i;
                        }
                      }

                      // --- ENERGY-FIRST METRICS (มาตรฐาน) ---
                      // 1) พยายามใช้มิเตอร์ energy (kWh) -> รวมเฉพาะส่วนเพิ่มขึ้น (handle reset)
                      final entries = mapRaw.entries
                          .map((e) => MapEntry(int.tryParse(e.key.toString()), e.value))
                          .where((e) => e.key != null && e.key! >= startTs && e.key! < endTs)
                          .toList()
                        ..sort((a, b) => a.key!.compareTo(b.key!));

                      double totalEnergyKWh = 0.0;
                      double? prevEnergy;
                      for (final e in entries) {
                        final v = e.value;
                        if (v is Map) {
                          final mv = Map<dynamic, dynamic>.from(v);
                          final en = mv['energy'];
                          if (en is num) {
                            final cur = en.toDouble();
                            if (prevEnergy != null) {
                              final d = cur - prevEnergy!;
                              if (d.isFinite && d > 0) totalEnergyKWh += d;
                            }
                            prevEnergy = cur;
                          }
                        }
                      }
                      // 2) ถ้าไม่มี energy ให้ fallback จากกราฟ: sum(hourlyAvg W)*1h /1000 = kWh
                      if (totalEnergyKWh == 0.0) {
                        final sumHourlyW = hourlyAvg.fold<double>(0, (s, v) => s + v);
                        totalEnergyKWh = sumHourlyW / 1000.0;
                      }

                      // 3) ค่าที่สรุปจาก energy
                      final double totalPowerW = totalEnergyKWh * 1000.0; // Wh ตลอดทั้งวัน
                      final double avgPowerW = totalPowerW / 24.0; // W

                      final Widget chart = _buildLineChart(spots, maxY, startOfDay);

                      // Portrait: horizontal scroll to avoid overlap
                      const double tickWidth = 52.0;
                      final double screenW = viewport.maxWidth;
                      final double chartWidthPortrait =
                          math.max(screenW, 24 * tickWidth);
                      final bool needScroll = chartWidthPortrait > screenW;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total: ${totalPowerW.toStringAsFixed(2)} W',
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
                            peakHour: peakHour,
                            minPowerW: minPowerW,
                            minHour: minHour,
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

  List<double> _hourlyAverageFrom(
    Map<dynamic, dynamic> raw, {
    required DateTime startOfDay,
    required DateTime endOfDay,
  }) {
    final sums = List<double>.filled(24, 0.0);
    final counts = List<int>.filled(24, 0);

    raw.forEach((k, v) {
      final int? ts = int.tryParse(k.toString());
      if (ts == null) return;

      final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: false);
      if (dt.isBefore(startOfDay) || !dt.isBefore(endOfDay)) return;

      final int hour = dt.hour;
      final map = (v is Map) ? Map<dynamic, dynamic>.from(v) : <String, dynamic>{};
      final num p = (map['power'] ?? 0);
      final double power = p.toDouble();

      sums[hour] += power;
      counts[hour] += 1;
    });

    return List<double>.generate(
      24,
      (i) => counts[i] > 0 ? sums[i] / counts[i] : 0.0,
    );
  }

  LineChart _buildLineChart(List<FlSpot> spots, double maxY, DateTime startOfDay) {
    final double yStep = math.max(1, (maxY / 5).ceilToDouble());
    final dateFmt = DateFormat('yyyy-MM-dd');
    final timeFmt = DateFormat('HH:00');

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 23,
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => touched.map((spot) {
              final int hour = spot.x.toInt().clamp(0, 23);
              final dt = startOfDay.add(Duration(hours: hour));
              return LineTooltipItem(
                '${DateFormat('yyyy-MM-dd HH:00').format(dt)}  —  ${spot.y.toStringAsFixed(2)} W',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            }).toList(),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: yStep,
          verticalInterval: 2,
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
              reservedSize: 44,
              interval: 2,
              getTitlesWidget: (value, _) {
                final int v = value.toInt();
                if (v < 0 || v > 23) return const SizedBox.shrink();
                final dt = startOfDay.add(Duration(hours: v));
                final bool major = (v % 6 == 0) || v == 23;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (major)
                      Text(
                        dateFmt.format(dt),
                        style: const TextStyle(fontSize: 10, color: Colors.black87),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      timeFmt.format(dt),
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

  Widget _buildSummaryGrid({
    required double totalEnergyKWh,
    required double totalPowerW,
    required double avgPowerW,
    required double peakPowerW,
    required int peakHour,
    required double minPowerW,
    required int minHour,
  }) {
    final items = <_SummaryItem>[
      _SummaryItem(
        title: 'Total Energy',
        value: '${totalEnergyKWh.toStringAsFixed(2)} kWh',
        icon: Icons.battery_full_outlined,
        color: const Color(0xFF2E7D32),
      ),
      _SummaryItem(
        title: 'Total Power',
        value: '${totalPowerW.toStringAsFixed(2)} W',
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
        value:
            '${peakPowerW.toStringAsFixed(2)} W @ ${peakHour.toString().padLeft(2, '0')}:00',
        icon: Icons.trending_up,
        color: const Color(0xFFD32F2F),
      ),
      _SummaryItem(
        title: 'Min',
        value:
            '${minPowerW.toStringAsFixed(2)} W @ ${minHour.toString().padLeft(2, '0')}:00',
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
    super.key,
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
