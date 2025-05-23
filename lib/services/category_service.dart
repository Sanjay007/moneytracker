import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../models/budget_category.dart';

class CategoryService {
  static const String _categoriesKey = 'budget_categories';

  // Get default categories
  static List<BudgetCategory> getDefaultCategories() {
    return [
      BudgetCategory(
        name: 'Food',
        amount: 0,
        color: Colors.orange,
        icon: Icons.restaurant,
      ),
      BudgetCategory(
        name: 'Transportation',
        amount: 0,
        color: Colors.blue,
        icon: Icons.directions_car,
      ),
      BudgetCategory(
        name: 'Entertainment',
        amount: 0,
        color: Colors.purple,
        icon: Icons.movie,
      ),
      BudgetCategory(
        name: 'Shopping',
        amount: 0,
        color: Colors.pink,
        icon: Icons.shopping_bag,
      ),
      BudgetCategory(
        name: 'Health',
        amount: 0,
        color: Colors.green,
        icon: Icons.local_hospital,
      ),
      BudgetCategory(
        name: 'Education',
        amount: 0,
        color: Colors.indigo,
        icon: Icons.school,
      ),
    ];
  }

  // Get all categories (default + custom)
  Future<List<BudgetCategory>> getAllCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = prefs.getStringList(_categoriesKey) ?? [];
    
    List<BudgetCategory> customCategories = categoriesJson.map((json) {
      final Map<String, dynamic> map = jsonDecode(json);
      return BudgetCategory(
        name: map['name'] ?? '',
        amount: (map['amount'] ?? 0.0).toDouble(),
        color: Color(map['color'] ?? Colors.grey.value),
        icon: IconData(map['icon'] ?? Icons.category.codePoint, fontFamily: 'MaterialIcons'),
      );
    }).toList();
    
    // Combine default and custom categories
    List<BudgetCategory> allCategories = [...getDefaultCategories(), ...customCategories];
    return allCategories;
  }

  // Save custom category
  Future<void> saveCustomCategory(BudgetCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = prefs.getStringList(_categoriesKey) ?? [];
    
    // Convert category to map
    final categoryMap = {
      'name': category.name,
      'amount': category.amount,
      'color': category.color.value,
      'icon': category.icon.codePoint,
    };
    
    // Add new category
    categoriesJson.add(jsonEncode(categoryMap));
    
    // Save to SharedPreferences
    await prefs.setStringList(_categoriesKey, categoriesJson);
  }

  // Update custom category
  Future<void> updateCustomCategory(String oldName, BudgetCategory newCategory) async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = prefs.getStringList(_categoriesKey) ?? [];
    
    // Find and update the category
    for (int i = 0; i < categoriesJson.length; i++) {
      final Map<String, dynamic> map = jsonDecode(categoriesJson[i]);
      if (map['name'] == oldName) {
        final categoryMap = {
          'name': newCategory.name,
          'amount': newCategory.amount,
          'color': newCategory.color.value,
          'icon': newCategory.icon.codePoint,
        };
        categoriesJson[i] = jsonEncode(categoryMap);
        break;
      }
    }
    
    // Save updated categories
    await prefs.setStringList(_categoriesKey, categoriesJson);
  }

  // Delete custom category
  Future<void> deleteCustomCategory(String categoryName) async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = prefs.getStringList(_categoriesKey) ?? [];
    
    // Remove the category
    categoriesJson.removeWhere((json) {
      final Map<String, dynamic> map = jsonDecode(json);
      return map['name'] == categoryName;
    });
    
    // Save updated categories
    await prefs.setStringList(_categoriesKey, categoriesJson);
  }

  // Check if category is custom (not default)
  bool isCustomCategory(String categoryName) {
    final defaultNames = getDefaultCategories().map((c) => c.name).toList();
    return !defaultNames.contains(categoryName);
  }

  // Get available icons for categories
  static List<IconData> getCategoryIcons() {
    return [
      Icons.restaurant,
      Icons.directions_car,
      Icons.movie,
      Icons.shopping_bag,
      Icons.local_hospital,
      Icons.school,
      Icons.work,
      Icons.home,
      Icons.pets,
      Icons.sports_esports,
      Icons.fitness_center,
      Icons.flight,
      Icons.hotel,
      Icons.local_gas_station,
      Icons.phone,
      Icons.wifi,
      Icons.electric_bolt,
      Icons.water_drop,
      Icons.shopping_cart,
      Icons.card_giftcard,
      Icons.savings,
      Icons.volunteer_activism,
      Icons.child_care,
      Icons.elderly,
      Icons.auto_fix_high,
    ];
  }

  // Get available colors for categories
  static List<Color> getCategoryColors() {
    return [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.grey,
      Colors.blueGrey,
    ];
  }
} 