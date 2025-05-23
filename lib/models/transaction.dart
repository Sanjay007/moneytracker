import 'package:flutter/material.dart';
import 'package:moneytracker/models/budget_category.dart';

class Transaction {
  final String id;
  final double amount;
  final String remarks;
  final DateTime date;
  final BudgetCategory category;
  final IconData? icon;
  final Color? iconColor;

  Transaction({
    required this.id,
    required this.amount,
    required this.remarks,
    required this.date,
    required this.category,
    this.icon,
    this.iconColor,
  });

  // Copy constructor for creating a copy with some fields changed
  Transaction copyWith({
    String? id,
    double? amount,
    String? remarks,
    DateTime? date,
    BudgetCategory? category,
    IconData? icon,
    Color? iconColor,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      remarks: remarks ?? this.remarks,
      date: date ?? this.date,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
    );
  }

  // For comparison purposes
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transaction &&
        other.id == id &&
        other.amount == amount &&
        other.remarks == remarks &&
        other.date == date &&
        other.category == category &&
        other.icon == icon &&
        other.iconColor == iconColor;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        amount.hashCode ^
        remarks.hashCode ^
        date.hashCode ^
        category.hashCode ^
        icon.hashCode ^
        iconColor.hashCode;
  }

  @override
  String toString() {
    return 'Transaction(id: $id, amount: $amount, remarks: $remarks, date: $date, category: $category, icon: $icon, iconColor: $iconColor)';
  }
} 