import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moneytracker/models/budget_category.dart';
import 'package:moneytracker/models/transaction.dart';
import 'package:moneytracker/models/account.dart';
import 'package:moneytracker/services/account_service.dart';
import 'package:moneytracker/services/category_service.dart';
import 'package:intl/intl.dart';

class SetBudgetScreen extends StatefulWidget {
  final bool isAccountSetup;
  final Account? accountToEdit;

  const SetBudgetScreen({Key? key, this.isAccountSetup = false, this.accountToEdit}) : super(key: key);

  @override
  _SetBudgetScreenState createState() => _SetBudgetScreenState();
}

class _SetBudgetScreenState extends State<SetBudgetScreen> {
  final PageController _pageController = PageController();
  final List<String> _quickAmounts = ['500', '1000', '1500', '2000', '2500', '3000'];
  
  // Sample transaction data for demonstration
  final List<Transaction> sampleTransactions = [
    Transaction(
      id: '1',
      amount: 85.50,
      remarks: 'Dinner at restaurant',
      date: DateTime(2024, 1, 15),
      category: BudgetCategory(name: 'Food & Dining', amount: 200, color: Colors.orange, icon: Icons.restaurant),
    ),
    Transaction(
      id: '2',
      amount: 25.00,
      remarks: 'Coffee shop',
      date: DateTime(2024, 1, 14),
      category: BudgetCategory(name: 'Food & Dining', amount: 200, color: Colors.orange, icon: Icons.restaurant),
    ),
    Transaction(
      id: '3',
      amount: 150.75,
      remarks: 'Grocery shopping',
      date: DateTime(2024, 1, 13),
      category: BudgetCategory(name: 'Food & Dining', amount: 200, color: Colors.orange, icon: Icons.restaurant),
    ),
    Transaction(
      id: '4',
      amount: 45.20,
      remarks: 'Gas station',
      date: DateTime(2024, 1, 12),
      category: BudgetCategory(name: 'Transportation', amount: 150, color: Colors.blue, icon: Icons.directions_car),
    ),
  ];

  final AccountService _accountService = AccountService();
  final CategoryService _categoryService = CategoryService();
  
  // Account setup controllers
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _totalBudgetController = TextEditingController();
  final TextEditingController _currentBalanceController = TextEditingController();
  
  String? _selectedBank;
  bool _isLoading = false;
  
  // Budget categories and their amounts
  Map<String, double> _categoryAmounts = {};
  
  List<BudgetCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    
    // If editing an account, pre-populate the fields
    if (widget.accountToEdit != null) {
      _accountNumberController.text = widget.accountToEdit!.accountNumber;
      _totalBudgetController.text = widget.accountToEdit!.totalBudget.toString();
      _currentBalanceController.text = widget.accountToEdit!.currentBalance.toString();
      _selectedBank = widget.accountToEdit!.bankName;
    }
    
    // Load categories
    _loadCategories();
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _totalBudgetController.dispose();
    _currentBalanceController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    if (widget.isAccountSetup || widget.accountToEdit != null) {
      if (_accountNumberController.text.trim().isEmpty) {
        _showErrorDialog('Please enter account number');
        return false;
      }
      
      if (_selectedBank == null) {
        _showErrorDialog('Please select a bank');
        return false;
      }
      
      if (_totalBudgetController.text.trim().isEmpty) {
        _showErrorDialog('Please enter total budget');
        return false;
      }
      
      if (_currentBalanceController.text.trim().isEmpty) {
        _showErrorDialog('Please enter current balance');
        return false;
      }

      final totalBudget = double.tryParse(_totalBudgetController.text);
      final currentBalance = double.tryParse(_currentBalanceController.text);
      
      if (totalBudget == null || totalBudget <= 0) {
        _showErrorDialog('Please enter a valid budget amount');
        return false;
      }
      
      if (currentBalance == null || currentBalance < 0) {
        _showErrorDialog('Please enter a valid balance amount');
        return false;
      }
    }
    
    return true;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAccount() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.isAccountSetup || widget.accountToEdit != null) {
        final account = Account(
          id: widget.accountToEdit?.id ?? _accountService.generateAccountId(),
          accountNumber: _accountNumberController.text.trim(),
          bankName: _selectedBank!,
          totalBudget: double.parse(_totalBudgetController.text),
          currentBalance: double.parse(_currentBalanceController.text),
          createdAt: widget.accountToEdit?.createdAt ?? DateTime.now(),
        );

        await _accountService.saveAccount(account);
        
        // Show success and navigate back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.accountToEdit != null 
                ? 'Account updated successfully!' 
                : 'Account setup completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        // Handle regular budget setting (existing functionality)
        Navigator.pop(context);
      }
    } catch (e) {
      _showErrorDialog('Failed to save account: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.accountToEdit != null 
              ? 'Edit Account' 
              : widget.isAccountSetup 
                  ? 'Account Setup' 
                  : 'Set Budget',
          style: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isAccountSetup || widget.accountToEdit != null) ...[
              // Account Setup Section
              Text(
                widget.accountToEdit != null 
                    ? 'Edit your bank account' 
                    : 'Set up your bank account',
                style: GoogleFonts.roboto(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              Text(
                widget.accountToEdit != null
                    ? 'Update your bank account details'
                    : 'Enter your bank details to get started with budget tracking',
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              SizedBox(height: 30),

              // Account Number Field
              _buildTextField(
                controller: _accountNumberController,
                label: 'Account Number',
                hint: 'Enter your account number',
                icon: Icons.account_balance,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              SizedBox(height: 20),

              // Bank Selection Dropdown
              _buildBankDropdown(),
              SizedBox(height: 20),

              // Total Budget Field
              _buildTextField(
                controller: _totalBudgetController,
                label: 'Total Monthly Budget',
                hint: 'Enter your monthly budget',
                icon: Icons.account_balance_wallet,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                prefix: '₹',
              ),
              SizedBox(height: 20),

              // Current Balance Field
              _buildTextField(
                controller: _currentBalanceController,
                label: 'Current Account Balance',
                hint: 'Enter your current balance',
                icon: Icons.account_balance_wallet_outlined,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                prefix: '₹',
              ),
              SizedBox(height: 30),
            ],

            // Budget Categories Section (show only if not account setup)
            if (!widget.isAccountSetup && widget.accountToEdit == null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Set Budget Categories',
                      style: GoogleFonts.roboto(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: ElevatedButton.icon(
                      onPressed: _showAddCategoryDialog,
                      icon: Icon(Icons.add, size: 16),
                      label: Text(
                        'Add',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size(0, 0),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              
              ..._categories.map((category) => _buildCategoryCard(category)),
              SizedBox(height: 30),
            ],

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.accountToEdit != null 
                            ? 'Update Account'
                            : widget.isAccountSetup 
                                ? 'Create Account' 
                                : 'Save Budget',
                        style: GoogleFonts.roboto(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? prefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: Color(0xFF6C5CE7)),
              prefixText: prefix,
              prefixStyle: GoogleFonts.roboto(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: Colors.white,
            ),
            style: GoogleFonts.roboto(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBankDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Bank',
          style: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedBank,
            hint: Text(
              'Choose your bank',
              style: GoogleFonts.roboto(color: Colors.grey[600]),
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.account_balance, color: Color(0xFF6C5CE7)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: Colors.white,
            ),
            items: _accountService.getSupportedBanks().map((bank) {
              return DropdownMenuItem<String>(
                value: bank,
                child: Text(
                  bank,
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedBank = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(BudgetCategory category) {
    final isCustomCategory = _categoryService.isCustomCategory(category.name);
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(category.icon, color: category.color, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Set monthly budget',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Flexible(
                flex: 1,
                child: Container(
                  constraints: BoxConstraints(
                    minWidth: 80,
                    maxWidth: 120,
                  ),
                  child: TextFormField(
                    initialValue: _categoryAmounts[category.name]?.toString() ?? '',
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '₹0',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      isDense: true,
                    ),
                    style: TextStyle(fontSize: 12),
                    onChanged: (value) {
                      final amount = double.tryParse(value) ?? 0;
                      setState(() {
                        _categoryAmounts[category.name] = amount;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          
          // Edit/Delete buttons for custom categories
          if (isCustomCategory) ...[
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: TextButton.icon(
                    onPressed: () => _editCategory(category),
                    icon: Icon(Icons.edit, size: 14, color: Colors.blue),
                    label: Text(
                      'Edit',
                      style: GoogleFonts.roboto(color: Colors.blue, fontSize: 11),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                SizedBox(width: 4),
                Flexible(
                  child: TextButton.icon(
                    onPressed: () => _deleteCategory(category),
                    icon: Icon(Icons.delete, size: 14, color: Colors.red),
                    label: Text(
                      'Delete',
                      style: GoogleFonts.roboto(color: Colors.red, fontSize: 11),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Category Icon
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              transaction.category.icon,
              color: Colors.purple,
              size: 24,
            ),
          ),
          SizedBox(width: 12),
          
          // Transaction Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.category.name,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  transaction.remarks,
                  style: GoogleFonts.montserrat(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy').format(transaction.date),
                  style: GoogleFonts.montserrat(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Amount
          Text(
            '\$${transaction.amount.toStringAsFixed(2)}',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.getAllCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      print('Error loading categories: $e');
      // Fall back to default categories
      setState(() {
        _categories = CategoryService.getDefaultCategories();
      });
    }
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AddEditCategoryDialog(
        onSave: (category) async {
          try {
            await _categoryService.saveCustomCategory(category);
            await _loadCategories();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Category added successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to add category: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  void _editCategory(BudgetCategory category) {
    showDialog(
      context: context,
      builder: (context) => AddEditCategoryDialog(
        categoryToEdit: category,
        onSave: (updatedCategory) async {
          try {
            if (_categoryService.isCustomCategory(category.name)) {
              await _categoryService.updateCustomCategory(category.name, updatedCategory);
            } else {
              // For default categories, we can't edit them, so show a message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Cannot edit default categories'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            await _loadCategories();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Category updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update category: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  void _deleteCategory(BudgetCategory category) {
    if (!_categoryService.isCustomCategory(category.name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot delete default categories'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Category',
          style: GoogleFonts.roboto(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${category.name}" category?\n\nThis action cannot be undone.',
          style: GoogleFonts.roboto(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _categoryService.deleteCustomCategory(category.name);
                Navigator.pop(context);
                await _loadCategories();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Category deleted successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete category: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class AddEditCategoryDialog extends StatefulWidget {
  final BudgetCategory? categoryToEdit;
  final Function(BudgetCategory) onSave;

  const AddEditCategoryDialog({
    Key? key,
    this.categoryToEdit,
    required this.onSave,
  }) : super(key: key);

  @override
  _AddEditCategoryDialogState createState() => _AddEditCategoryDialogState();
}

class _AddEditCategoryDialogState extends State<AddEditCategoryDialog> {
  final TextEditingController _nameController = TextEditingController();
  Color _selectedColor = Colors.blue;
  IconData _selectedIcon = Icons.category;

  @override
  void initState() {
    super.initState();
    if (widget.categoryToEdit != null) {
      _nameController.text = widget.categoryToEdit!.name;
      _selectedColor = widget.categoryToEdit!.color;
      _selectedIcon = widget.categoryToEdit!.icon;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.categoryToEdit != null ? 'Edit Category' : 'Add Category',
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 16),

              // Category Name Field
              Text(
                'Category Name',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Enter category name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  isDense: true,
                ),
              ),
              SizedBox(height: 16),

              // Color Selection
              Text(
                'Color',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              Container(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: CategoryService.getCategoryColors().length,
                  itemBuilder: (context, index) {
                    final color = CategoryService.getCategoryColors()[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                        });
                      },
                      child: Container(
                        margin: EdgeInsets.only(right: 8),
                        width: 35,
                        height: 35,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: _selectedColor == color
                              ? Border.all(color: Colors.black, width: 2)
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 16),

              // Icon Selection
              Text(
                'Icon',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              Container(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: CategoryService.getCategoryIcons().length,
                  itemBuilder: (context, index) {
                    final icon = CategoryService.getCategoryIcons()[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIcon = icon;
                        });
                      },
                      child: Container(
                        margin: EdgeInsets.only(right: 8),
                        width: 35,
                        height: 35,
                        decoration: BoxDecoration(
                          color: _selectedIcon == icon
                              ? _selectedColor.withOpacity(0.2)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: _selectedIcon == icon
                              ? Border.all(color: _selectedColor, width: 2)
                              : Border.all(color: Colors.grey[300]!),
                        ),
                        child: Icon(
                          icon,
                          color: _selectedIcon == icon ? _selectedColor : Colors.grey[600],
                          size: 18,
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Please enter a category name'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final category = BudgetCategory(
                        name: _nameController.text.trim(),
                        amount: widget.categoryToEdit?.amount ?? 0,
                        color: _selectedColor,
                        icon: _selectedIcon,
                      );

                      widget.onSave(category);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(widget.categoryToEdit != null ? 'Update' : 'Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}