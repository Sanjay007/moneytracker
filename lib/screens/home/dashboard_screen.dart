// Dashboard Screen (Home Tab)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moneytracker/screens/budget/set_budget_screen.dart';
import 'package:moneytracker/screens/transaction/edit_transaction_screen.dart';
import 'package:moneytracker/screens/category/category_detail_screen.dart';
import 'package:moneytracker/widgets/budget_progress_widget.dart';
import 'package:moneytracker/models/transaction.dart';
import 'package:moneytracker/models/budget_category.dart';
import 'package:moneytracker/models/account.dart';
import 'package:moneytracker/models/database_models.dart';
import 'package:moneytracker/services/account_service.dart';
import 'package:moneytracker/services/database_service.dart';
import 'package:intl/intl.dart';
import 'package:moneytracker/screens/sms/sms_transactions_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AccountService _accountService = AccountService();
  final DatabaseService _databaseService = DatabaseService.instance;
  Account? _currentAccount;
  bool _isLoadingAccount = true;
  List<TransactionDB> _todayTransactions = [];
  bool _isLoadingTransactions = true;
  
  // Sample categories data
  final List<BudgetCategory> _categories = [
    BudgetCategory(
      name: 'Fitness',
      amount: 200,
      color: Colors.red,
      icon: Icons.fitness_center,
    ),
    BudgetCategory(
      name: 'Income',
      amount: 500,
      color: Colors.green,
      icon: Icons.attach_money,
    ),
    BudgetCategory(
      name: 'Food',
      amount: 300,
      color: Colors.orange,
      icon: Icons.shopping_basket,
    ),
    BudgetCategory(
      name: 'Charity',
      amount: 1500,
      color: Colors.pink,
      icon: Icons.favorite,
    ),
  ];

  // Sample transactions data
  List<Transaction> _transactions = [
    Transaction(
      id: '1',
      amount: -50.0,
      remarks: 'Monthly gym membership',
      date: DateTime.now().subtract(Duration(days: 2)),
      category: BudgetCategory(
        name: 'Fitness',
        amount: 200,
        color: Colors.red,
        icon: Icons.fitness_center,
      ),
    ),
    Transaction(
      id: '2',
      amount: 60.0,
      remarks: 'Freelance payment',
      date: DateTime.now().subtract(Duration(days: 1)),
      category: BudgetCategory(
        name: 'Income',
        amount: 500,
        color: Colors.green,
        icon: Icons.attach_money,
      ),
    ),
    Transaction(
      id: '3',
      amount: -25.75,
      remarks: 'Grocery shopping',
      date: DateTime.now(),
      category: BudgetCategory(
        name: 'Food',
        amount: 300,
        color: Colors.orange,
        icon: Icons.shopping_basket,
      ),
    ),
    Transaction(
      id: '4',
      amount: -200.0,
      remarks: 'Fitness first',
      date: DateTime.now().subtract(Duration(days: 1)),
      icon: Icons.fitness_center,
      iconColor: Colors.red,
      category: BudgetCategory(
        name: 'Charity',
        amount: 1500,
        color: Colors.pink,
        icon: Icons.favorite,
      ),
    ),
    Transaction(
      id: '5',
      amount: -200.0,
      remarks: 'Transfer wise',
      date: DateTime.now().subtract(Duration(days: 3)),
      icon: Icons.arrow_upward,
      iconColor: Colors.blue,
      category: BudgetCategory(
        name: 'Charity',
        amount: 1500,
        color: Colors.pink,
        icon: Icons.favorite,
      ),
    ),
    Transaction(
      id: '6',
      amount: -200.0,
      remarks: 'Transfer wise',
      date: DateTime.now().subtract(Duration(days: 5)),
      icon: Icons.arrow_upward,
      iconColor: Colors.blue,
      category: BudgetCategory(
        name: 'Charity',
        amount: 1000,
        color: Colors.pink,
        icon: Icons.favorite,
      ),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkAccountSetup();
    _loadTodayTransactions();
  }

  Future<void> _checkAccountSetup() async {
    setState(() => _isLoadingAccount = true);
    
    try {
      final hasAccount = await _accountService.hasAnyAccount();
      
      if (!hasAccount) {
        // Navigate to account setup
        _navigateToAccountSetup();
      } else {
        // Load current account
        final account = await _accountService.getActiveAccount();
        setState(() {
          _currentAccount = account;
        });
      }
    } catch (e) {
      print('Error checking account setup: $e');
    } finally {
      setState(() => _isLoadingAccount = false);
    }
  }

  Future<void> _navigateToAccountSetup() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SetBudgetScreen(isAccountSetup: true),
      ),
    );
    
    if (result == true) {
      // Account was created successfully, reload
      _checkAccountSetup();
    }
  }

  Future<void> _showAccountOptions() async {
    final accounts = await _accountService.getAllAccounts();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Manage Accounts',
              style: GoogleFonts.roboto(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 20),
            
            // Current accounts list
            ...accounts.map((account) => _buildAccountTile(account)),
            
            SizedBox(height: 10),
            
            // Add new account button
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF6C5CE7).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add, color: Color(0xFF6C5CE7)),
              ),
              title: Text(
                'Add New Account',
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _navigateToAccountSetup();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountTile(Account account) {
    final isActive = _currentAccount?.id == account.id;
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive ? Color(0xFF6C5CE7).withOpacity(0.1) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: isActive ? Border.all(color: Color(0xFF6C5CE7)) : null,
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive ? Color(0xFF6C5CE7) : Colors.grey[400],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.account_balance,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          account.bankName,
          style: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isActive ? Color(0xFF6C5CE7) : Colors.black87,
          ),
        ),
        subtitle: Text(
          account.maskedAccountNumber,
          style: GoogleFonts.roboto(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Edit button
            IconButton(
              icon: Icon(Icons.edit, size: 18, color: Colors.blue),
              onPressed: () => _editAccount(account),
              tooltip: 'Edit Account',
            ),
            // Delete button (only if not active and not the only account)
            if (!isActive)
              IconButton(
                icon: Icon(Icons.delete, size: 18, color: Colors.red),
                onPressed: () => _deleteAccount(account),
                tooltip: 'Delete Account',
              ),
            // Active indicator
            if (isActive)
              Icon(Icons.check_circle, color: Color(0xFF6C5CE7), size: 20),
          ],
        ),
        onTap: () async {
          if (!isActive) {
            await _accountService.setActiveAccount(account.id);
            setState(() {
              _currentAccount = account;
            });
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAccount) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
          ),
        ),
      );
    }

    if (_currentAccount == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_wallet,
                size: 80,
                color: Colors.grey[400],
              ),
              SizedBox(height: 20),
              Text(
                'No Account Found',
                style: GoogleFonts.roboto(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Please set up your account to continue',
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: _navigateToAccountSetup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Set Up Account',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good Morning, Parzival',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              'Have a good day!',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: Colors.grey[200],
              child: Icon(Icons.notifications_outlined, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentAccount!.bankName,
                            style: GoogleFonts.roboto(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      Text(
                            _currentAccount!.maskedAccountNumber,
                            style: GoogleFonts.roboto(
                          color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _showAccountOptions,
                            child: Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.swap_horiz,
                                color: Colors.white70,
                                size: 16,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                      Icon(Icons.more_horiz, color: Colors.white70),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Current Balance 💰',
                    style: GoogleFonts.roboto(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _currentAccount!.formattedBalance.replaceAll('₹', ''),
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'INR',
                    style: GoogleFonts.roboto(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      _buildActionButton(Icons.add, 'Deposit'),
                      SizedBox(width: 15),
                      _buildActionButton(Icons.trending_up, 'Transfer'),
                      SizedBox(width: 15),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => SmsTransactionsScreen()),
                          );
                        },
                        child: _buildActionButton(Icons.sms, 'SMS'),
                      ),
                      SizedBox(width: 15),
                      _buildActionButton(Icons.apps, 'More'),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),
            
            // Budget Progress Widget - Normal scenario
            Center(
              child: BudgetProgressWidget(
                totalBudget: 6000.0,
                spentAmount: 2335.20,
              ),
            ),
            SizedBox(height: 20),
            
            // Budget Section
            Container(
              padding: EdgeInsets.all(20),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set a financial budget',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Setting a budget helps you track your financial goals with finances.',
                    style: GoogleFonts.montserrat(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SetBudgetScreen()),
      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Set budget'),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            // Transactions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                      'Today\'s Transactions',
                      style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                    ),
                    Text(
                      DateFormat('EEEE, MMM dd, yyyy').format(DateTime.now()),
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'view all',
                    style: GoogleFonts.montserrat(
                      color: Color(0xFF6C5CE7),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Today's Transactions List
            _isLoadingTransactions
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        color: Color(0xFF6C5CE7),
                      ),
                    ),
                  )
                : _todayTransactions.isEmpty
                    ? Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No transactions today',
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Your daily transactions will appear here',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: _todayTransactions.map((transaction) => _buildDatabaseTransactionItem(transaction)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.montserrat(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final Color textColor = transaction.amount < 0 ? Colors.red : Colors.green;
    final String amountText = transaction.amount < 0 
        ? '-\$${transaction.amount.abs().toStringAsFixed(2)}'
        : '+\$${transaction.amount.toStringAsFixed(2)}';
    
    return GestureDetector(
      onTap: () => _navigateToEditTransaction(transaction),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => _navigateToCategoryDetail(transaction.category),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: transaction.category.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(transaction.category.icon, color: transaction.category.color, size: 20),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _navigateToCategoryDetail(transaction.category),
                        child: Text(
                          transaction.category.name,
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                            color: Color(0xFF6C5CE7),
                            decoration: TextDecoration.underline,
                          ),
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
                    ],
                  ),
                ),
                Text(
                  amountText,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Divider(height: 1, color: Colors.grey[200]),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  DateFormat('dd MMM yyyy').format(transaction.date),
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToEditTransaction(Transaction transaction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditTransactionScreen(
          transaction: transaction,
        ),
      ),
    ).then((result) {
      // Handle the result if the transaction was updated
      if (result != null && result is Transaction) {
        setState(() {
          int index = _transactions.indexWhere((t) => t.id == result.id);
          if (index != -1) {
            _transactions[index] = result;
          }
        });
      }
    });
  }

  void _navigateToCategoryDetail(BudgetCategory category) {
    // Set background color based on category - light pink for Charity to match the image
    Color backgroundColor = Colors.grey[50]!; // Default background
    if (category.name == 'Charity') {
      backgroundColor = Color(0xFFFDF2F8); // Light pink background
    }
    
    // Get transactions for this category
    final categoryTransactions = _transactions.where((t) => t.category.name == category.name).toList();
    
    // Calculate spent amount for this category
    final spentAmount = categoryTransactions.fold<double>(0.0, (sum, transaction) => sum + transaction.amount.abs());
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryDetailScreen(
          categoryName: category.name,
          categoryIcon: String.fromCharCode(category.icon.codePoint),
          transactionCount: categoryTransactions.length,
          budgetAmount: category.amount,
          spentAmount: spentAmount,
          backgroundColor: backgroundColor,
          transactions: categoryTransactions,
        ),
      ),
    );
  }

  Future<void> _editAccount(Account account) async {
    Navigator.pop(context); // Close the account selection modal
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SetBudgetScreen(
          isAccountSetup: true,
          accountToEdit: account,
        ),
      ),
    );
    
    if (result == true) {
      // Account was updated successfully, reload
      _checkAccountSetup();
    }
  }

  Future<void> _deleteAccount(Account account) async {
    final accounts = await _accountService.getAllAccounts();
    
    // Don't allow deletion if it's the only account
    if (accounts.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot delete the only account. Add another account first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Account',
          style: GoogleFonts.roboto(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this account?\n\n${account.bankName}\n${account.maskedAccountNumber}\n\nThis action cannot be undone.',
          style: GoogleFonts.roboto(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _accountService.deleteAccount(account.id);
        Navigator.pop(context); // Close the account selection modal
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload accounts
        _checkAccountSetup();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadTodayTransactions() async {
    setState(() => _isLoadingTransactions = true);
    
    try {
      final transactions = await _databaseService.getTransactionsForToday();
      setState(() {
        _todayTransactions = transactions;
      });
    } catch (e) {
      print('Error loading today\'s transactions: $e');
      // Keep empty list if error occurs
      setState(() {
        _todayTransactions = [];
      });
    } finally {
      setState(() => _isLoadingTransactions = false);
    }
  }

  Widget _buildDatabaseTransactionItem(TransactionDB transaction) {
    final Color textColor = transaction.type == 'debit' ? Colors.red : Colors.green;
    final String amountText = transaction.type == 'debit' 
        ? '-₹${transaction.amount.toStringAsFixed(2)}'
        : '+₹${transaction.amount.toStringAsFixed(2)}';
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
                  color: Color(transaction.categoryColorValue).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
                child: Icon(
                  IconData(transaction.categoryIconCodePoint, fontFamily: 'MaterialIcons'),
                  color: Color(transaction.categoryColorValue),
                  size: 20,
                ),
          ),
          SizedBox(width: 12),
          Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.categoryName,
                      style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                        color: Color(0xFF6C5CE7),
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
                    if (transaction.merchant != null) ...[
                      SizedBox(height: 2),
                      Text(
                        'at ${transaction.merchant}',
                        style: GoogleFonts.montserrat(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                amountText,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Divider(height: 1, color: Colors.grey[200]),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (transaction.referenceNumber != null)
                Text(
                  'Ref: ${transaction.referenceNumber}',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[500],
            ),
          ),
          Text(
                DateFormat('hh:mm a').format(transaction.date),
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}