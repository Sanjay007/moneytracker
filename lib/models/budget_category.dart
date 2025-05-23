import 'package:flutter/material.dart';

class BudgetCategory {
  final String name;
  final double amount;
  final Color color;
  final IconData icon;

  BudgetCategory({
    required this.name,
    required this.amount,
    required this.color,
    required this.icon,
  });

  // Copy constructor for creating a copy with some fields changed
  BudgetCategory copyWith({
    String? name,
    double? amount,
    Color? color,
    IconData? icon,
  }) {
    return BudgetCategory(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      color: color ?? this.color,
      icon: icon ?? this.icon,
    );
  }

  // For comparison purposes
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BudgetCategory &&
        other.name == name &&
        other.amount == amount &&
        other.color == color &&
        other.icon == icon;
  }

  @override
  int get hashCode {
    return name.hashCode ^ amount.hashCode ^ color.hashCode ^ icon.hashCode;
  }

  @override
  String toString() {
    return 'BudgetCategory(name: $name, amount: $amount, color: $color, icon: $icon)';
  }
} 