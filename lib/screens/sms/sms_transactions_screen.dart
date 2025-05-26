import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/account.dart';
import '../../models/database_models.dart';
import '../../services/sms_reader_service.dart';
import '../../services/account_service.dart';
import '../../services/database_service.dart';

class SmsTransactionsScreen extends StatefulWidget {
  @override
  _SmsTransactionsScreenState createState() => _SmsTransactionsScreenState();
}

class _SmsTransactionsScreenState extends State<SmsTransactionsScreen> {
  final SmsReaderService _smsService = SmsReaderService();
  final AccountService _accountService = AccountService();
  final DatabaseService _databaseService = DatabaseService.instance;
  
  List<SmsTransactionDB> _transactions = [];
  List<SmsTransactionDB> _allTransactions = [];
  Account? _currentAccount;
  bool _isLoading = false;
  bool _hasPermission = false;
  String _filter = 'pending'; // 'all', 'pending', 'accepted', 'rejected'
  DateTime _selectedDate = DateTime.now(); // Add selected date for filtering
  Map<String, List<SmsTransactionDB>> _transactionsByDate = {}; // Group transactions by date
  
  // New view mode properties
  String _viewMode = 'all'; // 'all', 'by_date'
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();

  // New properties for hybrid loading
  bool _isCheckingNewSms = false;
  int _newSmsCount = 0;
  DateTime? _lastProcessedDate;

  @override
  void initState() {
    super.initState();
    _loadCurrentAccount();
  }

  Future<void> _loadCurrentAccount() async {
    try {
      final account = await _accountService.getActiveAccount();
      setState(() {
        _currentAccount = account;
      });
      
      if (account != null) {
        await _loadTransactions();
      }
    } catch (e) {
      _showErrorDialog('Error loading account: $e');
    }
  }

  Future<void> _loadTransactions() async {
    if (_currentAccount == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      print('🔄 Starting SMS transaction loading...');
      
      // Step 1: Always load existing transactions from database first
      print('📂 Loading existing transactions from database...');
      final existingTransactions = await _databaseService.getAllSmsTransactions();
      print('📊 Found ${existingTransactions.length} existing transactions in database');
      
      // Step 2: Process existing transactions first
      await _processTransactions(existingTransactions);
      setState(() {
        _isLoading = false;
      });
      
      // Step 3: Check SMS permission
      await _checkSmsPermissionAndScan(existingTransactions.isEmpty);
      
    } catch (e) {
      print('❌ Error loading transactions: $e');
      _showErrorDialog('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkSmsPermissionAndScan(bool isDatabaseEmpty) async {
    if (_currentAccount == null) return;
    
    setState(() => _isCheckingNewSms = true);
    
    try {
      print('📱 Checking SMS permission...');
      _hasPermission = await _smsService.hasSmsPermission();
      
      if (!_hasPermission) {
        print('🔐 Requesting SMS permission...');
        _hasPermission = await _smsService.requestSmsPermission();
      }
      
      if (_hasPermission) {
        if (isDatabaseEmpty) {
          print('📱 Database is empty - reading ALL SMS from phone...');
          await _scanAllSmsMessages();
        } else {
          print('📱 Database has data - scanning for NEW SMS messages only...');
          await _scanForNewSmsMessages();
        }
      } else {
        print('❌ SMS permission denied, using only database transactions');
      }
      
    } catch (e) {
      print('❌ Error checking SMS permission: $e');
    } finally {
      setState(() => _isCheckingNewSms = false);
    }
  }

  Future<void> _scanAllSmsMessages() async {
    if (_currentAccount == null) return;
    
    try {
      print('🔍 Reading ALL SMS messages from phone (database was empty)...');
      
      // Read ALL SMS transactions for this account (no date filter)
      final allSmsTransactions = await _smsService.getTransactionsForAccount(
        _currentAccount!.accountNumber,
      );
      
      if (allSmsTransactions.isEmpty) {
        print('ℹ️ No SMS transactions found for this account');
        return;
      }
      
      print('📱 Found ${allSmsTransactions.length} total SMS transactions');
      int insertedCount = 0;
      
      // Insert all SMS transactions as new
      for (final smsTransaction in allSmsTransactions) {
        final dbTransaction = SmsTransactionDB(
          id: smsTransaction.id,
          rawMessage: smsTransaction.message,
          bankName: smsTransaction.bankName,
          accountNumber: smsTransaction.accountNumber,
          amount: smsTransaction.amount,
          transactionType: smsTransaction.transactionType,
          date: smsTransaction.date,
          merchant: smsTransaction.merchant,
          referenceNumber: smsTransaction.referenceNumber,
          userRemarks: smsTransaction.userRemarks,
          status: 'pending', // All new SMS start as pending
        );
        
        // Insert (should all be new since database was empty)
        final wasInserted = await _databaseService.insertNewSmsTransaction(dbTransaction);
        if (wasInserted) {
          insertedCount++;
        }
      }
      
      print('✅ Inserted $insertedCount SMS transactions into database');
      
      // Set last processed date to now since we've processed all historical SMS
      await _databaseService.updateLastProcessedSmsDate(DateTime.now());
      
      // Reload transactions to show all the new ones
      if (insertedCount > 0) {
        setState(() {
          _newSmsCount = insertedCount;
        });
        await _reloadTransactionsFromDatabase();
      }
      
    } catch (e) {
      print('❌ Error reading all SMS messages: $e');
    }
  }

  Future<void> _scanForNewSmsMessages() async {
    if (_currentAccount == null) return;
    
    try {
      // Get last processed SMS date
      _lastProcessedDate = await _databaseService.getLastProcessedSmsDate();
      print('📅 Last processed SMS date: ${_lastProcessedDate?.toIso8601String() ?? "never"}');
      
      // Get new SMS messages since last processed date
      final newSmsTransactions = await _smsService.getNewSmsTransactionsSince(
        _lastProcessedDate,
        _currentAccount!.accountNumber,
      );
      
      if (newSmsTransactions.isEmpty) {
        print('ℹ️ No new SMS transactions found since last scan');
        return;
      }
      
      print('📱 Found ${newSmsTransactions.length} new SMS transactions');
      int insertedCount = 0;
      
      // Insert only new SMS transactions
      for (final smsTransaction in newSmsTransactions) {
        final dbTransaction = SmsTransactionDB(
          id: smsTransaction.id,
          rawMessage: smsTransaction.message,
          bankName: smsTransaction.bankName,
          accountNumber: smsTransaction.accountNumber,
          amount: smsTransaction.amount,
          transactionType: smsTransaction.transactionType,
          date: smsTransaction.date,
          merchant: smsTransaction.merchant,
          referenceNumber: smsTransaction.referenceNumber,
          userRemarks: smsTransaction.userRemarks,
          status: 'pending', // New SMS start as pending
        );
        
        // Insert only if it doesn't exist (preserves user status/remarks)
        final wasInserted = await _databaseService.insertNewSmsTransaction(dbTransaction);
        if (wasInserted) {
          insertedCount++;
        }
      }
      
      print('✅ Inserted $insertedCount new SMS transactions into database');
      
      // Update last processed date to now
      await _databaseService.updateLastProcessedSmsDate(DateTime.now());
      
      // Reload transactions to show new ones
      if (insertedCount > 0) {
        setState(() {
          _newSmsCount = insertedCount;
        });
        await _reloadTransactionsFromDatabase();
      }
      
    } catch (e) {
      print('❌ Error scanning for new SMS messages: $e');
    }
  }

  Future<void> _reloadTransactionsFromDatabase() async {
    try {
      print('🔄 Reloading transactions from database...');
      final allTransactions = await _databaseService.getAllSmsTransactions();
      await _processTransactions(allTransactions);
      
      // Show success message for new transactions
      if (_newSmsCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found $_newSmsCount new SMS transactions'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                setState(() {
                  _viewMode = 'all';
                  _filter = 'all';
                  _applyFilter();
                });
              },
            ),
          ),
        );
        _newSmsCount = 0; // Reset counter
      }
      
    } catch (e) {
      print('❌ Error reloading transactions: $e');
    }
  }

  // Manual refresh method for user-triggered refresh
  Future<void> _manualRefresh() async {
    setState(() {
      _newSmsCount = 0;
    });
    // Use the current state of transactions to determine if database is empty
    await _checkSmsPermissionAndScan(_allTransactions.isEmpty);
  }

  Future<void> _processTransactions(List<SmsTransactionDB> transactions) async {
    // Group transactions by date
    _transactionsByDate.clear();
    for (final transaction in transactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(transaction.date);
      if (!_transactionsByDate.containsKey(dateKey)) {
        _transactionsByDate[dateKey] = [];
      }
      _transactionsByDate[dateKey]!.add(transaction);
    }
    
    setState(() {
      _allTransactions = transactions;
    });

    // For "by_date" mode, ensure selected date has transactions or switch to most recent
    if (_viewMode == 'by_date') {
      final currentDateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
      if (_transactionsByDate[currentDateKey] == null || _transactionsByDate[currentDateKey]!.isEmpty) {
        final mostRecentDate = await _databaseService.getMostRecentSmsTransactionDate();
        if (mostRecentDate != null) {
          setState(() {
            _selectedDate = mostRecentDate;
          });
        }
      }
    }

    _applyFilter();
  }

  void _applyFilter() {
    List<SmsTransactionDB> filteredTransactions;

    if (_viewMode == 'all') {
      // Show all transactions sorted by latest date
      filteredTransactions = List.from(_allTransactions);
      filteredTransactions.sort((a, b) => b.date.compareTo(a.date));
    } else {
      // Show transactions for selected date
      final selectedDateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
      filteredTransactions = _transactionsByDate[selectedDateKey] ?? [];
    }
    
    // Apply status filter
    switch (_filter) {
      case 'pending':
        _transactions = filteredTransactions.where((t) => t.isPending).toList();
        break;
      case 'accepted':
        _transactions = filteredTransactions.where((t) => t.isAccepted).toList();
        break;
      case 'rejected':
        _transactions = filteredTransactions.where((t) => t.isRejected).toList();
        break;
      default:
        _transactions = filteredTransactions;
    }

    setState(() {});
  }

  void _updateTransactionStatus(SmsTransactionDB transaction, String newStatus, String? remarks) async {
    setState(() {
      final index = _allTransactions.indexWhere((t) => t.id == transaction.id);
      if (index != -1) {
        _allTransactions[index] = transaction.copyWith(
          status: newStatus,
          userRemarks: remarks ?? transaction.userRemarks,
        );
      }
    });

    // Persist changes to database
    try {
      await _databaseService.updateSmsTransactionStatus(
        transaction.id,
        newStatus,
        remarks: remarks,
      );
      print('✅ Transaction status updated in database: ${transaction.id} -> $newStatus');
      
      // Update account balance when transaction is accepted
      if (newStatus == 'accepted' && _currentAccount != null) {
        print('💰 Transaction accepted, updating account balance...');
        
        try {
          // Method 1: Try to update balance from SMS data
          await _databaseService.updateAccountBalanceFromSms(_currentAccount!.id);
          
          // Method 2: If no balance found in SMS, use account service calculation
          final acceptedTransactions = await _databaseService.getAcceptedSmsTransactions();
          if (acceptedTransactions.isNotEmpty) {
            await _accountService.updateBalanceFromSmsTransactions(
              _currentAccount!.id, 
              acceptedTransactions
            );
          }
          
          print('✅ Account balance updated successfully');
          
          // Show success message with balance update info
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Transaction accepted and account balance updated'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          
        } catch (e) {
          print('❌ Failed to update account balance: $e');
          // Still show success for transaction acceptance, but warn about balance
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Transaction accepted, but balance update failed'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      
    } catch (e) {
      print('❌ Failed to update transaction status in database: $e');
      // Optionally show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save changes to database'),
          backgroundColor: Colors.red,
        ),
      );
    }

    _applyFilter();
  }

  void _showAddRemarksDialog(SmsTransactionDB transaction) {
    final TextEditingController remarksController = TextEditingController(
      text: transaction.userRemarks ?? ''
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Remarks',
          style: GoogleFonts.roboto(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaction: ${transaction.formattedAmount}',
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: remarksController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter remarks for this transaction...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.all(12),
              ),
              style: GoogleFonts.roboto(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateTransactionStatus(
                transaction,
                transaction.status,
                remarksController.text.trim().isEmpty ? null : remarksController.text.trim(),
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Remarks updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
            ),
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showConfirmationDialog(SmsTransactionDB transaction, String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${action == 'accepted' ? 'Accept' : 'Reject'} Transaction',
          style: GoogleFonts.roboto(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to ${action == 'accepted' ? 'accept' : 'reject'} this transaction of ${transaction.formattedAmount}?',
          style: GoogleFonts.roboto(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateTransactionStatus(transaction, action, transaction.userRemarks);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'accepted' ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(action == 'accepted' ? 'Accept' : 'Reject'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Error',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Text(
          message,
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.montserrat(
                color: Color(0xFF6C5CE7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'SMS Processing Info',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Database Transactions', '${_allTransactions.length}'),
            _buildInfoRow('SMS Permission', _hasPermission ? 'Granted' : 'Denied'),
            if (_lastProcessedDate != null)
              _buildInfoRow(
                'Last SMS Scan',
                DateFormat('dd-MMM-yy HH:mm').format(_lastProcessedDate!),
              ),
            SizedBox(height: 12),
            Text(
              'Transactions are automatically saved to preserve your acceptance/rejection status and remarks.',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.montserrat(
                color: Color(0xFF6C5CE7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
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
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _applyFilter();
      });
    }
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF6C5CE7),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        // Filter transactions based on date range
        _filterTransactionsByDateRange();
      });
    }
  }

  void _filterTransactionsByDateRange() {
    // Create a filtered list of transactions within the date range
    final filteredTransactions = _allTransactions.where((transaction) {
      final transactionDate = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );
      final startDate = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final endDate = DateTime(_endDate.year, _endDate.month, _endDate.day);
      
      return transactionDate.isAfter(startDate.subtract(Duration(days: 1))) &&
             transactionDate.isBefore(endDate.add(Duration(days: 1)));
    }).toList();

    // Rebuild the transactions by date map with filtered data
    _transactionsByDate.clear();
    for (final transaction in filteredTransactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(transaction.date);
      if (!_transactionsByDate.containsKey(dateKey)) {
        _transactionsByDate[dateKey] = [];
      }
      _transactionsByDate[dateKey]!.add(transaction);
    }

    _applyFilter();
  }

  void _onViewModeChanged(String newMode) {
    setState(() {
      _viewMode = newMode;
      if (newMode == 'by_date') {
        // Reset to single date selection
        _selectedDate = DateTime.now();
      }
      _applyFilter();
    });
  }

  List<SmsTransactionDB> _getFilteredTransactionsByStatus(String status) {
    List<SmsTransactionDB> filteredTransactions;

    if (_viewMode == 'all') {
      // Use all transactions
      filteredTransactions = _allTransactions;
    } else {
      // Use transactions for selected date
      final selectedDateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
      filteredTransactions = _transactionsByDate[selectedDateKey] ?? [];
    }
    
    switch (status) {
      case 'pending':
        return filteredTransactions.where((t) => t.isPending).toList();
      case 'accepted':
        return filteredTransactions.where((t) => t.isAccepted).toList();
      case 'rejected':
        return filteredTransactions.where((t) => t.isRejected).toList();
      default:
        return filteredTransactions;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    'SMS Transactions',
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isCheckingNewSms) ...[
                  SizedBox(width: 8),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
                    ),
                  ),
                ],
              ],
            ),
            if (_currentAccount != null)
              Text(
                '${_currentAccount!.bankName} - ${_currentAccount!.maskedAccountNumber}',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Manual refresh button with new SMS indicator
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  _isCheckingNewSms ? Icons.sync : Icons.refresh,
                  color: _isCheckingNewSms ? Color(0xFF6C5CE7) : Colors.black54,
                ),
                onPressed: _isCheckingNewSms ? null : _manualRefresh,
                tooltip: _isCheckingNewSms ? 'Checking for new SMS...' : 'Scan for new SMS',
              ),
              if (_newSmsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_newSmsCount',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Settings/Info button
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.black54),
            onPressed: _showInfoDialog,
            tooltip: 'SMS Processing Info',
          ),
        ],
      ),
      body: _currentAccount == null
          ? _buildNoAccountView()
          : _isLoading
              ? _buildLoadingView()
              : _hasPermission
                  ? _buildTransactionsList()
                  : _buildPermissionDeniedView(),
    );
  }

  Widget _buildNoAccountView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance,
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
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              'Please set up your account first to view SMS transactions.',
              style: GoogleFonts.roboto(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sms_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 20),
            Text(
              'SMS Permission Required',
              style: GoogleFonts.roboto(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              'To read bank transaction SMS messages, please grant SMS permission.',
              style: GoogleFonts.roboto(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: _loadTransactions,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Grant Permission',
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

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
          ),
          SizedBox(height: 20),
          Text(
            'Reading SMS messages...',
            style: GoogleFonts.roboto(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    return Column(
      children: [
        // View Mode Selector
        Container(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'View Mode:',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Color(0xFF6C5CE7)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _viewMode,
                      isExpanded: true,
                      icon: Icon(Icons.arrow_drop_down, color: Color(0xFF6C5CE7)),
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          _onViewModeChanged(newValue);
                        }
                      },
                      items: [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Show All (Latest First)'),
                        ),
                        DropdownMenuItem(
                          value: 'by_date',
                          child: Text('Show by Date'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Date selector - conditional based on view mode
        if (_viewMode == 'by_date') ...[
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _showDatePicker,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Color(0xFF6C5CE7)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: Color(0xFF6C5CE7), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate),
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: Color(0xFF6C5CE7)),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Date navigation buttons
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDate = _selectedDate.subtract(Duration(days: 1));
                          _applyFilter();
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.chevron_left, color: Colors.grey[600], size: 18),
                      ),
                    ),
                    SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        final tomorrow = _selectedDate.add(Duration(days: 1));
                        if (tomorrow.isBefore(DateTime.now().add(Duration(days: 1)))) {
                          setState(() {
                            _selectedDate = tomorrow;
                            _applyFilter();
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.chevron_right, color: Colors.grey[600], size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
        
        // Filter buttons
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Pending', 'pending', _getFilteredTransactionsByStatus('pending').length),
                SizedBox(width: 8),
                _buildFilterChip('Accepted', 'accepted', _getFilteredTransactionsByStatus('accepted').length),
                SizedBox(width: 8),
                _buildFilterChip('Rejected', 'rejected', _getFilteredTransactionsByStatus('rejected').length),
                SizedBox(width: 8),
                _buildFilterChip('All', 'all', _getFilteredTransactionsByStatus('all').length),
              ],
            ),
          ),
        ),

        // Transactions count
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _viewMode == 'all' 
                      ? '${_transactions.length} transactions found (all dates)'
                      : '${_transactions.length} transactions found for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),

        // Transactions list
        Expanded(
          child: _transactions.isEmpty
              ? _buildEmptyView()
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    return _buildTransactionCard(_transactions[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filter = value;
          _applyFilter();
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF6C5CE7) : Colors.white,
          border: Border.all(
            color: isSelected ? Color(0xFF6C5CE7) : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
            SizedBox(width: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.3) : Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: GoogleFonts.roboto(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    final hasDataOnOtherDates = _allTransactions.isNotEmpty;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 20),
          Text(
            hasDataOnOtherDates 
                ? (_viewMode == 'all' ? 'No matching transactions' : 'No transactions for this date')
                : 'No transactions found',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            hasDataOnOtherDates
                ? (_viewMode == 'all' 
                    ? 'No ${_filter == 'all' ? '' : _filter + ' '}transactions found matching your criteria.'
                    : 'No ${_filter == 'all' ? '' : _filter + ' '}transactions found for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}.')
                : 'No ${_filter == 'all' ? '' : _filter + ' '}transactions found for this account.',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          if (hasDataOnOtherDates && _viewMode == 'by_date') ...[
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                final mostRecentDate = await _databaseService.getMostRecentSmsTransactionDate();
                if (mostRecentDate != null) {
                  setState(() {
                    _selectedDate = mostRecentDate;
                    _applyFilter();
                  });
                }
              },
              icon: Icon(Icons.history, size: 18),
              label: Text('Show Recent Transactions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
          if (hasDataOnOtherDates && _viewMode == 'all') ...[
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _filter = 'all';
                  _applyFilter();
                });
              },
              icon: Icon(Icons.visibility, size: 18),
              label: Text('Show All Transactions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionCard(SmsTransactionDB transaction) {
    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.schedule;
    
    if (transaction.isAccepted) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (transaction.isRejected) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    }

    // Determine category info for consistent display
    final categoryName = _getCategoryNameFromTransaction(transaction);
    final categoryIcon = IconData(_getCategoryIconFromTransaction(transaction), fontFamily: 'MaterialIcons');
    final categoryColor = Color(_getCategoryColorFromTransaction(transaction));

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
        border: transaction.isPending 
            ? Border.all(color: Colors.orange.withOpacity(0.3), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main transaction row - matching dashboard style
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  categoryIcon,
                  color: categoryColor,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            categoryName,
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              color: Color(0xFF6C5CE7),
                            ),
                          ),
                        ),
                        // Status indicator
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 14, color: statusColor),
                            SizedBox(width: 4),
                            Text(
                              transaction.status.toUpperCase(),
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      transaction.userRemarks ?? 'SMS Transaction',
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
                transaction.isDebit 
                    ? '-${transaction.formattedAmount}'
                    : '+${transaction.formattedAmount}',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: transaction.isDebit ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 10),
          Divider(height: 1, color: Colors.grey[200]),
          SizedBox(height: 10),
          
          // Bottom row with reference and time - matching dashboard style
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (transaction.referenceNumber != null)
                Expanded(
                  child: Text(
                    'Ref: ${transaction.referenceNumber}',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                    overflow: TextOverflow.ellipsis,
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

          // Additional SMS-specific information
          if (transaction.userRemarks != null) ...[
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.note, size: 14, color: Colors.blue),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'User Remarks: ${transaction.userRemarks}',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              // Add/Edit Remarks button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAddRemarksDialog(transaction),
                  icon: Icon(
                    transaction.userRemarks != null ? Icons.edit_note : Icons.add_comment,
                    size: 16,
                  ),
                  label: Text(
                    transaction.userRemarks != null ? 'Edit Remarks' : 'Add Remarks',
                    style: GoogleFonts.montserrat(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFF6C5CE7),
                    side: BorderSide(color: Color(0xFF6C5CE7)),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                ),
              ),
              
              if (transaction.isPending) ...[
                SizedBox(width: 8),
                // Accept button - Icon only
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: () => _showConfirmationDialog(transaction, 'accepted'),
                    icon: Icon(Icons.check, size: 20),
                    color: Colors.white,
                    padding: EdgeInsets.all(8),
                    constraints: BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    tooltip: 'Accept Transaction',
                  ),
                ),
                SizedBox(width: 8),
                // Reject button - Icon only
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: () => _showConfirmationDialog(transaction, 'rejected'),
                    icon: Icon(Icons.close, size: 20),
                    color: Colors.white,
                    padding: EdgeInsets.all(8),
                    constraints: BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    tooltip: 'Reject Transaction',
                  ),
                ),
              ],
            ],
          ),

          // View SMS details (expandable)
          SizedBox(height: 8),
          ExpansionTile(
            title: Text(
              'View SMS Details',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Color(0xFF6C5CE7),
              ),
            ),
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  transaction.rawMessage,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  softWrap: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper methods for category determination (matching dashboard logic)
  String _getCategoryNameFromTransaction(SmsTransactionDB smsTransaction) {
    if (smsTransaction.merchant != null) {
      final merchant = smsTransaction.merchant!.toLowerCase();
      
      // Food & Dining
      if (merchant.contains('restaurant') || merchant.contains('cafe') || 
          merchant.contains('food') || merchant.contains('pizza') ||
          merchant.contains('mcdonalds') || merchant.contains('kfc') ||
          merchant.contains('swiggy') || merchant.contains('zomato')) {
        return 'Food & Dining';
      }
      
      // Shopping
      if (merchant.contains('amazon') || merchant.contains('flipkart') ||
          merchant.contains('shop') || merchant.contains('store') ||
          merchant.contains('mall') || merchant.contains('retail')) {
        return 'Shopping';
      }
      
      // Transportation
      if (merchant.contains('uber') || merchant.contains('ola') ||
          merchant.contains('petrol') || merchant.contains('fuel') ||
          merchant.contains('transport') || merchant.contains('metro')) {
        return 'Transportation';
      }
      
      // ATM/Bank
      if (merchant.contains('atm') || merchant.contains('bank') ||
          merchant.contains('branch')) {
        return 'ATM/Bank';
      }
    }
    
    // Default category based on transaction type
    return smsTransaction.isDebit ? 'General Expense' : 'Income';
  }

  // Helper method to get category icon
  int _getCategoryIconFromTransaction(SmsTransactionDB smsTransaction) {
    final categoryName = _getCategoryNameFromTransaction(smsTransaction);
    
    switch (categoryName) {
      case 'Food & Dining':
        return Icons.restaurant.codePoint;
      case 'Shopping':
        return Icons.shopping_bag.codePoint;
      case 'Transportation':
        return Icons.directions_car.codePoint;
      case 'ATM/Bank':
        return Icons.account_balance.codePoint;
      case 'Income':
        return Icons.attach_money.codePoint;
      default:
        return Icons.payment.codePoint;
    }
  }

  // Helper method to get category color
  int _getCategoryColorFromTransaction(SmsTransactionDB smsTransaction) {
    final categoryName = _getCategoryNameFromTransaction(smsTransaction);
    
    switch (categoryName) {
      case 'Food & Dining':
        return Colors.orange.value;
      case 'Shopping':
        return Colors.purple.value;
      case 'Transportation':
        return Colors.blue.value;
      case 'ATM/Bank':
        return Colors.green.value;
      case 'Income':
        return Colors.green.value;
      default:
        return Colors.grey.value;
    }
  }
} 