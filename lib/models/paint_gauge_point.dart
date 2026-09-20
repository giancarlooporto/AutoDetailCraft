class PaintGaugePoint {
  final String id;
  final String label;
  final double initialMicrons;
  final double postPolishMicrons;

  const PaintGaugePoint({
    required this.id,
    required this.label,
    required this.initialMicrons,
    required this.postPolishMicrons,
  });

  double get micronsRemoved => (initialMicrons - postPolishMicrons).clamp(0.0, 999.0);

  PaintGaugePoint copyWith({
    String? id,
    String? label,
    double? initialMicrons,
    double? postPolishMicrons,
  }) {
    return PaintGaugePoint(
      id: id ?? this.id,
      label: label ?? this.label,
      initialMicrons: initialMicrons ?? this.initialMicrons,
      postPolishMicrons: postPolishMicrons ?? this.postPolishMicrons,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'initialMicrons': initialMicrons,
    'postPolishMicrons': postPolishMicrons,
  };

  factory PaintGaugePoint.fromJson(Map<String, dynamic> json) => PaintGaugePoint(
    id: json['id'] as String? ?? 'point',
    label: json['label'] as String? ?? '',
    initialMicrons: (json['initialMicrons'] as num?)?.toDouble() ?? 120.0,
    postPolishMicrons: (json['postPolishMicrons'] as num?)?.toDouble() ?? 116.0,
  );

  static List<PaintGaugePoint> default8Points({double initial = 122.0, double post = 119.0}) {
    return [
      PaintGaugePoint(id: 'hood', label: 'Hood', initialMicrons: initial, postPolishMicrons: post),
      PaintGaugePoint(id: 'roof', label: 'Roof', initialMicrons: initial, postPolishMicrons: post),
      PaintGaugePoint(id: 'trunk', label: 'Trunk', initialMicrons: initial, postPolishMicrons: post),
      PaintGaugePoint(id: 'front_left', label: 'Front-Left Fender/Door', initialMicrons: initial, postPolishMicrons: post),
      PaintGaugePoint(id: 'rear_left', label: 'Rear-Left Quarter', initialMicrons: initial, postPolishMicrons: post),
      PaintGaugePoint(id: 'front_right', label: 'Front-Right Fender/Door', initialMicrons: initial, postPolishMicrons: post),
      PaintGaugePoint(id: 'rear_right', label: 'Rear-Right Quarter', initialMicrons: initial, postPolishMicrons: post),
      PaintGaugePoint(id: 'bumpers', label: 'Front/Rear Bumpers', initialMicrons: initial, postPolishMicrons: post),
    ];
  }
}
