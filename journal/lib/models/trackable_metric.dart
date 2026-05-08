class TrackableMetric {
  int? id;
  String name;
  String unit;          // e.g. "kg", "L", "kcal", "/5"
  double? targetValue;  // optional goal (e.g. 55 for weight)
  int colorValue;       // ARGB int for line color
  Map<String, double> history; // {yyyy-MM-dd: value}

  TrackableMetric({
    this.id,
    required this.name,
    required this.unit,
    this.targetValue,
    required this.colorValue,
    Map<String, double>? history,
  }) : history = history ?? {};

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'unit': unit,
    'target_value': targetValue,
    'color_value': colorValue,
    'history': history,
  };

  factory TrackableMetric.fromMap(Map<String, dynamic> map) => TrackableMetric(
    id: map['id'],
    name: map['name'],
    unit: map['unit'] ?? '',
    targetValue: (map['target_value'] as num?)?.toDouble(),
    colorValue: map['color_value'] ?? 0xFFE8873A,
    history: (map['history'] as Map?)?.map(
      (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
    ) ?? {},
  );
}
