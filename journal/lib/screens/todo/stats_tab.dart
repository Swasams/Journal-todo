// ignore: unnecessary_import
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/todo_item.dart';
import '../../models/trackable_metric.dart';
import 'todo_theme.dart';

// Internal: a series that actually has data on the chart.
class _ChartedSeries {
  final _Series series;
  final List<double?> raw;
  final LineChartBarData bar;
  final bool isProjection; // True when this is the dashed weight target line.
  _ChartedSeries({
    required this.series,
    required this.raw,
    required this.bar,
    this.isProjection = false,
  });
}

// Weight goal anchors — used for the projected-loss reference line.
final DateTime _kWeightStartDate = DateTime(2026, 4, 26);
final DateTime _kWeightEndDate = DateTime(2026, 12, 31);
const double _kWeightStartKg = 70.0;
const double _kWeightEndKg = 55.0;

// A toggleable line series (either a metric or a habit).
class _Series {
  final String id;
  final String label;
  final Color color;
  final bool isMetric;
  final TrackableMetric? metric;
  final TodoItem? habit;
  final String unit;
  bool enabled;

  _Series({
    required this.id,
    required this.label,
    required this.color,
    required this.isMetric,
    this.metric,
    this.habit,
    this.unit = '',
    this.enabled = false,
  });
}

class StatsTab extends StatefulWidget {
  final List<TodoItem> todos;
  final List<TrackableMetric> metrics;
  final Map<String, List<int>> completions;
  final Future<void> Function(TrackableMetric m) onUpdateMetric;
  final Future<void> Function(int id) onDeleteMetric;
  final Future<void> Function() onReload;

  const StatsTab({
    super.key,
    required this.todos,
    required this.metrics,
    required this.completions,
    required this.onUpdateMetric,
    required this.onDeleteMetric,
    required this.onReload,
  });

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  late List<_Series> _series;
  // Range: how many weeks back to show
  int _weeksBack = 12;

  @override
  void initState() {
    super.initState();
    _series = _buildSeries(initial: true);
  }

  @override
  void didUpdateWidget(covariant StatsTab old) {
    super.didUpdateWidget(old);
    final fresh = _buildSeries(initial: false);
    // Preserve enabled state by id.
    final enabledIds =
        _series.where((s) => s.enabled).map((s) => s.id).toSet();
    for (final s in fresh) {
      if (enabledIds.contains(s.id)) s.enabled = true;
    }
    _series = fresh;
  }

  List<_Series> _buildSeries({required bool initial}) {
    final list = <_Series>[];
    for (final m in widget.metrics) {
      // Mood line is locked to brown — uneditable, since Mood is the
      // only fixed metric (no edit dialog). Other metrics use whatever
      // colour the user picked.
      final isMood = m.name.toLowerCase() == 'mood';
      list.add(_Series(
        id: 'm_${m.id}',
        label: m.name,
        color: isMood ? kBrown : Color(m.colorValue),
        isMetric: true,
        metric: m,
        unit: m.unit,
        enabled: initial && m.name == 'Weight', // pre-enable Weight
      ));
    }
    final habits = widget.todos.where((t) => t.isHabit).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    for (var i = 0; i < habits.length; i++) {
      // Use the habit's own picked colour for its trend line.
      list.add(_Series(
        id: 'h_${habits[i].id}',
        label: habits[i].title,
        color: Color(habits[i].colorValue),
        isMetric: false,
        habit: habits[i],
        unit: '%',
      ));
    }
    return list;
  }

  // Build week buckets. _weeksBack == 0 is the special "all of 2026" range.
  List<DateTime> _weekStarts() {
    if (_weeksBack == 0) {
      // Sunday on/before Jan 1 2026 = Dec 28 2025. 53 weeks fully covers 2026.
      final start = DateTime(2025, 12, 28);
      return List.generate(53, (i) => start.add(Duration(days: 7 * i)));
    }
    final now = DateTime.now();
    // anchor on Sunday so weeks line up like the Notion log
    final startOfThisWeek =
        DateTime(now.year, now.month, now.day - now.weekday % 7);
    return List.generate(_weeksBack,
        (i) => startOfThisWeek.subtract(Duration(days: 7 * (_weeksBack - 1 - i))));
  }

  // Returns y values for each week for a given series.
  // For metrics: average value in that week (null if no entry).
  // For habits: completion % in that week (capped at 1.0).
  List<double?> _yForSeries(_Series s, List<DateTime> weeks) {
    final values = <double?>[];
    for (final start in weeks) {
      final end = start.add(const Duration(days: 7));
      if (s.isMetric) {
        final m = s.metric!;
        final readings = <double>[];
        m.history.forEach((dateStr, v) {
          final d = parseDate(dateStr);
          if (!d.isBefore(start) && d.isBefore(end)) readings.add(v);
        });
        values.add(readings.isEmpty
            ? null
            : readings.reduce((a, b) => a + b) / readings.length);
      } else {
        final h = s.habit!;
        // Expected completions per week given intervalDays.
        final expected = (7.0 / h.intervalDays).clamp(1.0, 7.0);
        var actual = 0;
        for (var d = 0; d < 7; d++) {
          final day = start.add(Duration(days: d));
          if (day.isAfter(DateTime.now())) break;
          final list = widget.completions[formatDate(day)];
          if (list != null && list.contains(h.id)) actual++;
        }
        values.add((actual / expected).clamp(0.0, 1.5));
      }
    }
    return values;
  }

  // Normalize using a fixed [lo, hi] window. Values outside clamp.
  List<double?> _normalizeFixed(List<double?> raw, double lo, double hi) {
    if (hi == lo) return raw.map<double?>((v) => v == null ? null : 0.5).toList();
    return raw
        .map<double?>(
            (v) => v == null ? null : ((v - lo) / (hi - lo)).clamp(0.0, 1.0))
        .toList();
  }

  // Normalize a per-series y-list to [0,1] using its own min/max.
  List<double?> _normalize(List<double?> raw) {
    final present = raw.whereType<double>().toList();
    if (present.isEmpty) return raw;
    final lo = present.reduce((a, b) => a < b ? a : b);
    final hi = present.reduce((a, b) => a > b ? a : b);
    if (hi == lo) {
      return raw.map<double?>((v) => v == null ? null : 0.5).toList();
    }
    return raw
        .map<double?>((v) => v == null ? null : (v - lo) / (hi - lo))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _series.where((s) => s.enabled).toList();
    final weekStarts = _weekStarts();

    return ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          // Range selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Trends',
                  style: TextStyle(
                      color: kBrown,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      fontFamily: 'Montserrat')),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 4, label: Text('4w')),
                  ButtonSegment(value: 12, label: Text('12w')),
                  ButtonSegment(value: 0, label: Text('2026')),
                ],
                selected: {_weeksBack},
                onSelectionChanged: (s) =>
                    setState(() => _weeksBack = s.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected)
                          ? kSunsetPetal
                          : kFrostTint.withValues(alpha: 0.7)),
                  foregroundColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected)
                          ? Colors.white
                          : kBrown),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Chart — frosted glass over the morning gradient.
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: kFrostShadow,
            ),
            child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 24, 8),
                decoration: BoxDecoration(
                  color: kFrostTint.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kRosebudBlush, width: 1.5),
                ),
                child: SizedBox(
                  height: 240,
                  child: visible.isEmpty
                      ? Center(
                          child: Text(
                            'Toggle metrics or habits below to compare trends.',
                            style: TextStyle(
                                color: kBrown.withValues(alpha: 0.4)),
                          ),
                        )
                      : _buildChart(visible, weekStarts),
                ),
              ),
            ),
          ),
          ),

          if (visible.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Each line normalized to its own min–max so trends are comparable. Tap a card on the Todo tab for actual values.',
              style: TextStyle(
                  color: kBrown.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontStyle: FontStyle.italic),
            ),
          ],

          const SizedBox(height: 18),

          // Toggles — metrics
          _ToggleSection(
            title: 'Metrics',
            series: _series.where((s) => s.isMetric).toList(),
            onToggle: (s) => setState(() => s.enabled = !s.enabled),
          ),
          const SizedBox(height: 14),
          // Toggles — habits
          _ToggleSection(
            title: 'Habits',
            series: _series.where((s) => !s.isMetric).toList(),
            onToggle: (s) => setState(() => s.enabled = !s.enabled),
          ),

        ],
    );
  }

  Widget _buildChart(List<_Series> visible, List<DateTime> weekStarts) {
    // Build (series, rawValues, lineBar) tuples so tooltip can map back correctly.
    final charted = <_ChartedSeries>[];
    final weightEnabled = visible.any((s) =>
        s.isMetric && s.metric!.name.toLowerCase() == 'weight');

    for (final s in visible) {
      final raw = _yForSeries(s, weekStarts);
      final isWeight =
          s.isMetric && s.metric!.name.toLowerCase() == 'weight';
      final norm = isWeight
          ? _normalizeFixed(raw, _kWeightEndKg, _kWeightStartKg)
          : _normalize(raw);
      final spots = <FlSpot>[];
      for (var i = 0; i < norm.length; i++) {
        if (norm[i] != null) {
          spots.add(FlSpot(i.toDouble(), norm[i]!.clamp(0.0, 1.0)));
        }
      }
      if (spots.isEmpty) continue;
      charted.add(_ChartedSeries(
        series: s,
        raw: raw,
        bar: LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: s.color,
          barWidth: 2.5,
          dotData: FlDotData(
            getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
              radius: 3,
              color: s.color,
              strokeWidth: 0,
              strokeColor: Colors.transparent,
            ),
          ),
          belowBarData: BarAreaData(show: false),
        ),
      ));
    }

    // When Weight is enabled, append a dashed reference line for the
    // 70→55 kg target pace from Apr 26 → Dec 31 2026.
    if (weightEnabled) {
      final totalDays = _kWeightEndDate
          .difference(_kWeightStartDate)
          .inDays
          .toDouble();
      final raw = <double?>[];
      final spots = <FlSpot>[];
      for (var i = 0; i < weekStarts.length; i++) {
        final daysSinceStart =
            weekStarts[i].difference(_kWeightStartDate).inDays.toDouble();
        final progress = (daysSinceStart / totalDays).clamp(0.0, 1.0);
        // Higher weight maps to top (1.0) since we use [55, 70] window.
        final targetKg = _kWeightStartKg -
            (_kWeightStartKg - _kWeightEndKg) * progress;
        raw.add(targetKg);
        spots.add(FlSpot(i.toDouble(), 1 - progress));
      }
      const projColor = Color(0xFFD94F3A);
      charted.add(_ChartedSeries(
        isProjection: true,
        series: _Series(
          id: 'proj_weight',
          label: 'Target pace',
          color: projColor.withValues(alpha: 0.5),
          isMetric: true,
          unit: 'kg',
        ),
        raw: raw,
        bar: LineChartBarData(
          spots: spots,
          isCurved: false,
          color: projColor.withValues(alpha: 0.45),
          barWidth: 1.5,
          dashArray: const [6, 4],
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      ));
    }

    if (charted.isEmpty) {
      return Center(
        child: Text(
          'No data yet for selected lines.',
          style: TextStyle(color: kBrown.withValues(alpha: 0.4)),
        ),
      );
    }
    final lines = charted.map((c) => c.bar).toList();

    final labelStep = (weekStarts.length / 6).ceil().toDouble();

    return LineChart(LineChartData(
      minY: 0,
      maxY: 1.05,
      minX: 0,
      maxX: (weekStarts.length - 1).toDouble(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(
            color: kBrown.withValues(alpha: 0.07), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval: labelStep,
            getTitlesWidget: (v, meta) {
              final idx = v.toInt();
              if (idx < 0 || idx >= weekStarts.length) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 6,
                child: Text(
                  DateFormat('MMM d').format(weekStarts[idx]),
                  style: TextStyle(
                      color: kBrown.withValues(alpha: 0.55), fontSize: 9),
                ),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => kBrown.withValues(alpha: 0.92),
          getTooltipItems: (touched) {
            return touched.map((sp) {
              final c = charted[sp.barIndex];
              final ser = c.series;
              final rawV = c.raw[sp.x.toInt()];
              final rawStr = rawV == null
                  ? '—'
                  : ser.isMetric
                      ? '${_pretty(rawV)} ${ser.unit}'
                      : '${(rawV * 100).round()}%';
              return LineTooltipItem(
                '${ser.label}\n',
                TextStyle(
                    color: ser.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 11),
                children: [
                  TextSpan(
                    text: rawStr,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.normal,
                        fontSize: 11),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: lines,
    ));
  }

  String _pretty(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

// ── Toggle section ──────────────────────────────────────────────
class _ToggleSection extends StatelessWidget {
  final String title;
  final List<_Series> series;
  final void Function(_Series) onToggle;

  const _ToggleSection({
    required this.title,
    required this.series,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: kBrown,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: 'Montserrat')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: series.map((s) {
            return GestureDetector(
              onTap: () => onToggle(s),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: s.enabled
                      ? s.color
                      : kFrostTint.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: s.color, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: s.enabled ? Colors.white : s.color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.label,
                      style: TextStyle(
                        color: s.enabled ? Colors.white : kBrown,
                        fontSize: 11,
                        fontWeight: s.enabled
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

