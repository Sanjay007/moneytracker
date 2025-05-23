import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:moneytracker/models/budget_category.dart';
import 'package:moneytracker/models/transaction.dart';

class EditTransactionScreen extends StatefulWidget {
  final Transaction? transaction;

  const EditTransactionScreen({Key? key, this.transaction}) : super(key: key);

  @override
  _EditTransactionScreenState createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _remarksController;
  late DateTime _selectedDate;
  late BudgetCategory _selectedCategory;
  String _selectedType = 'Income';
  
  final List<BudgetCategory> _categories = [
    BudgetCategory(name: 'Food & Dining', amount: 200, color: Colors.orange, icon: Icons.restaurant),
    BudgetCategory(name: 'Transportation', amount: 150, color: Colors.blue, icon: Icons.directions_car),
    BudgetCategory(name: 'Shopping', amount: 300, color: Colors.pink, icon: Icons.shopping_bag),
    BudgetCategory(name: 'Entertainment', amount: 100, color: Colors.purple, icon: Icons.movie),
    BudgetCategory(name: 'Utilities', amount: 200, color: Colors.green, icon: Icons.home),
    BudgetCategory(name: 'Salary', amount: 500, color: Colors.green, icon: Icons.work),
    BudgetCategory(name: 'Other', amount: 100, color: Colors.grey, icon: Icons.category),
  ];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.transaction?.amount.abs().toString() ?? '',
    );
    _remarksController = TextEditingController(
      text: widget.transaction?.remarks ?? '',
    );
    _selectedDate = widget.transaction?.date ?? DateTime.now();
    
    // Find matching category from local _categories list by name
    if (widget.transaction?.category != null) {
      _selectedCategory = _categories.firstWhere(
        (category) => category.name == widget.transaction!.category.name,
        orElse: () => _categories.first,
      );
    } else {
      _selectedCategory = _categories.first;
    }
    
    _selectedType = widget.transaction != null && widget.transaction!.amount > 0 ? 'Income' : 'Expense';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.transaction == null ? 'Add Transaction' : 'Edit Transaction',
          style: GoogleFonts.montserrat(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type Selection (Income/Expense)
              Text(
                'Transaction Type',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedType = 'Income'),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedType == 'Income' ? Color(0xFF6C5CE7) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedType == 'Income' ? Color(0xFF6C5CE7) : Colors.grey[300]!,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Income',
                            style: GoogleFonts.montserrat(
                              color: _selectedType == 'Income' ? Colors.white : Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedType = 'Expense'),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedType == 'Expense' ? Color(0xFF6C5CE7) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedType == 'Expense' ? Color(0xFF6C5CE7) : Colors.grey[300]!,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Expense',
                            style: GoogleFonts.montserrat(
                              color: _selectedType == 'Expense' ? Colors.white : Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 24),
              
              // Category Selection
              Text(
                'Category',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<BudgetCategory>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF6C5CE7), width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem<BudgetCategory>(
                    value: category,
                    child: Row(
                      children: [
                        Icon(category.icon, color: Color(0xFF6C5CE7), size: 20),
                        SizedBox(width: 12),
                        Text(
                          category.name,
                          style: GoogleFonts.montserrat(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (BudgetCategory? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  }
                },
              ),
              
              SizedBox(height: 24),
              
              // Amount Input
              Text(
                'Amount',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  hintStyle: GoogleFonts.montserrat(color: Colors.grey),
                  prefixText: '\$ ',
                  prefixStyle: GoogleFonts.montserrat(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF6C5CE7), width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 24),
              
              // Remarks Input
              Text(
                'Remarks',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _remarksController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add remarks...',
                  hintStyle: GoogleFonts.montserrat(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF6C5CE7), width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                ),
              ),
              
              SizedBox(height: 24),
              
              // Date Selection
              Text(
                'Date',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('MMM dd, yyyy').format(_selectedDate),
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      Icon(Icons.calendar_today, color: Color(0xFF6C5CE7)),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 40),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6C5CE7),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.transaction == null ? 'Add Transaction' : 'Save Changes',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF6C5CE7),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            textTheme: GoogleFonts.montserratTextTheme(),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveTransaction() {
    if (_formKey.currentState!.validate()) {
      // Get the amount and apply sign based on type
      double amount = double.parse(_amountController.text);
      if (_selectedType == 'Expense') {
        amount = -amount.abs(); // Make sure expense is negative
      } else {
        amount = amount.abs(); // Make sure income is positive
      }

      final updatedTransaction = Transaction(
        id: widget.transaction?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        remarks: _remarksController.text,
        date: _selectedDate,
        category: _selectedCategory,
      );

      // Return the updated transaction to the calling screen
      Navigator.pop(context, updatedTransaction);
    }
  }
} 