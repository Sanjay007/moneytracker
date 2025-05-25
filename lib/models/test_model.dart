class TestModel {
  final String id;
  final String name;
  final DateTime createdAt;

  TestModel({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  // Convert TestModel to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create TestModel from Map
  factory TestModel.fromMap(Map<String, dynamic> map) {
    return TestModel(
      id: map['id'],
      name: map['name'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  @override
  String toString() {
    return 'TestModel{id: $id, name: $name, createdAt: $createdAt}';
  }
} 