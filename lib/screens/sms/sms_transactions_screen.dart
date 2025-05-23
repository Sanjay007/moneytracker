import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/sms_transaction.dart';
import '../../models/account.dart';
import '../../services/sms_reader_service.dart';
import '../../services/account_service.dart';

class SmsTransactionsScreen extends StatefulWidget {
  @override
  _SmsTransactionsScreenState createState() => _SmsTransactionsScreenState();
}

class _SmsTransactionsScreenState extends State<SmsTransactionsScreen> {
  final SmsReaderService _smsService = SmsReaderService();
  final AccountService _accountService = AccountService();
  
  List<SmsTransaction> _transactions = [];
  List<SmsTransaction> _allTransactions = [];
  Account? _currentAccount;
  bool _isLoading = false;
  bool _hasPermission = false;
  String _filter = 'pending'; // 'all', 'pending', 'accepted', 'rejected'

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
        _checkPermissionAndLoadTransactions();
      }
    } catch (e) {
      _showErrorDialog('Error loading account: $e');
    }
  }

  Future<void> _checkPermissionAndLoadTransactions() async {
    if (_currentAccount == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      _hasPermission = await _smsService.hasSmsPermission();
      
      if (!_hasPermission) {
        _hasPermission = await _smsService.requestSmsPermission();
      }
      
      if (_hasPermission) {
        await _loadTransactions();
      }
    } catch (e) {
      _showErrorDialog('Error: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadTransactions() async {
    if (_currentAccount == null) return;
    
    try {
      final transactions = await _smsService.getTransactionsForAccount(_currentAccount!.accountNumber);
      setState(() {
        _allTransactions = transactions;
        _applyFilter();
      });
    } catch (e) {
      _showErrorDialog('Failed to load transactions: $e');
    }
  }

  void _applyFilter() {
    switch (_filter) {
      case 'pending':
        _transactions = _allTransactions.where((t) => t.isPending).toList();
        break;
      case 'accepted':
        _transactions = _allTransactions.where((t) => t.isAccepted).toList();
        break;
      case 'rejected':
        _transactions = _allTransactions.where((t) => t.isRejected).toList();
        break;
      default:
        _transactions = _allTransactions;
    }
  }

  void _updateTransactionStatus(SmsTransaction transaction, String newStatus, String? remarks) {
    setState(() {
      final index = _allTransactions.indexWhere((t) => t.id == transaction.id);
      if (index != -1) {
        _allTransactions[index] = transaction.copyWith(
          status: newStatus,
          userRemarks: remarks ?? transaction.userRemarks,
        );
      }
      _applyFilter();
    });
  }

  void _showAddRemarksDialog(SmsTransaction transaction) {
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

  void _showConfirmationDialog(SmsTransaction transaction, String action) {
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Transaction ${action}'),
                  backgroundColor: action == 'accepted' ? Colors.green : Colors.red,
                ),
              );
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
            Text(
              'SMS Transactions',
              style: GoogleFonts.roboto(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (_currentAccount != null)
              Text(
                '${_currentAccount!.bankName} - ${_currentAccount!.maskedAccountNumber}',
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.black54),
            onPressed: _checkPermissionAndLoadTransactions,
          ),
        ],
      ),
      body: _currentAccount == null
          ? _buildNoAccountView()
          : !_hasPermission
              ? _buildPermissionDeniedView()
              : _isLoading
                  ? _buildLoadingView()
                  : _buildTransactionsList(),
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
              onPressed: _checkPermissionAndLoadTransactions,
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
        // Filter buttons
        Container(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Pending', 'pending', _allTransactions.where((t) => t.isPending).length),
                SizedBox(width: 8),
                _buildFilterChip('Accepted', 'accepted', _allTransactions.where((t) => t.isAccepted).length),
                SizedBox(width: 8),
                _buildFilterChip('Rejected', 'rejected', _allTransactions.where((t) => t.isRejected).length),
                SizedBox(width: 8),
                _buildFilterChip('All', 'all', _allTransactions.length),
              ],
            ),
          ),
        ),

        // Transactions count
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${_transactions.length} transactions found',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  color: Colors.grey[600],
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
            'No transactions found',
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'No ${_filter == 'all' ? '' : _filter + ' '}transactions found for this account.',
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(SmsTransaction transaction) {
    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.schedule;
    
    if (transaction.isAccepted) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (transaction.isRejected) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    }

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
            offset: Offset(0, 2),
          ),
        ],
        border: transaction.isPending 
            ? Border.all(color: Colors.orange.withOpacity(0.3), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with bank name, amount, and status
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.bankName,
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (transaction.accountNumber != null)
                      Text(
                        'Account: ${transaction.accountNumber}',
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: transaction.isDebit 
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      transaction.formattedAmount,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: transaction.isDebit ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      SizedBox(width: 4),
                      Text(
                        transaction.status.toUpperCase(),
                        style: GoogleFonts.roboto(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),

          // Transaction details
          Row(
            children: [
              Icon(
                transaction.isDebit ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: transaction.isDebit ? Colors.red : Colors.green,
              ),
              SizedBox(width: 4),
              Text(
                transaction.transactionType?.toUpperCase() ?? 'TRANSACTION',
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: transaction.isDebit ? Colors.red : Colors.green,
                ),
              ),
              Spacer(),
              Text(
                transaction.formattedDate,
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),

          if (transaction.merchant != null) ...[
            SizedBox(height: 8),
            Text(
              'Merchant: ${transaction.merchant}',
              style: GoogleFonts.roboto(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ],

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
                      'Remarks: ${transaction.userRemarks}',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
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
                    style: GoogleFonts.roboto(fontSize: 12),
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
              style: GoogleFonts.roboto(
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
                  transaction.message,
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 