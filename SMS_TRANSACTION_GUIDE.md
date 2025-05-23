# SMS Transaction Reader - Yes Bank Guide

## Overview
This feature allows you to automatically read and parse bank transaction SMS messages from your device, with special optimization for Yes Bank transactions.

## Features

### 🏦 **Multi-Bank Support**
- Yes Bank (optimized)
- HDFC Bank
- ICICI Bank
- Axis Bank
- State Bank of India (SBI)
- Kotak Bank

### 📱 **SMS Parsing Capabilities**
- **Amount Extraction**: Automatically detects transaction amounts
- **Transaction Type**: Identifies debit/credit transactions
- **Account Numbers**: Extracts masked account numbers
- **Merchant Details**: Identifies vendor/merchant names
- **Balance Information**: Shows available balance when available
- **Reference Numbers**: Captures transaction reference numbers

### 🔍 **Smart Filtering**
- Filter by specific banks (Yes Bank focus)
- Filter by transaction type (debit/credit)
- Date-based sorting (newest first)
- Search and categorization

## How to Use

### 1. **Access SMS Transactions**
- Open the Money Tracker app
- Go to Dashboard
- In the balance card, tap the "SMS" button
- Or navigate through the main menu

### 2. **Grant Permissions**
- The app will request SMS reading permission
- Tap "Grant Permission" 
- Accept the permission in the Android dialog

### 3. **View Transactions**
- All bank transactions will be loaded automatically
- Use filter chips to narrow down results:
  - **All Banks**: Show all detected bank transactions
  - **Yes Bank**: Show only Yes Bank transactions
  - **Debits**: Show only debit transactions
  - **Credits**: Show only credit transactions

### 4. **Quick Yes Bank Access**
- Tap "Show Yes Bank Transactions" button for direct access
- This filters and displays only Yes Bank SMS messages

## Yes Bank SMS Patterns

The app recognizes Yes Bank transactions from these sender patterns:
- `YESBNK`
- `YESBANK` 
- `YES-BANK`

### Example Yes Bank SMS Formats Supported:

```
1. "Rs 500.00 debited from A/c ***1234 on 15-Jan-24 at ATM. Available bal: Rs 5000.00"

2. "INR 1000.00 credited to your Yes Bank A/c ***5678 on 15-Jan-24. Ref: ABC123456789"

3. "Transaction of Rs 250.00 debited from ***9012 at AMAZON on 15-Jan-24. Bal: Rs 4500.00"
```

## Transaction Card Details

Each transaction card shows:
- **Bank Name**: Identified bank (Yes Bank, HDFC, etc.)
- **Amount**: Formatted amount with ₹ symbol
- **Transaction Type**: DEBIT/CREDIT with color coding
- **Date & Time**: Formatted date and time
- **Merchant**: Vendor/merchant name (if available)
- **Balance**: Account balance (if available)
- **Full SMS**: Expandable view of original SMS

## Data Extraction Patterns

### Amount Recognition:
- `Rs 500.00`, `INR 1000`, `₹250.00`
- `amount Rs 750`, `debited 500.00`

### Transaction Types:
- **Debit**: debited, withdrawn, spent, paid
- **Credit**: credited, deposited, received

### Account Numbers:
- `A/c ***1234`, `account 5678`, `***9012`

### Merchants:
- `at AMAZON`, `to FLIPKART`, `from PAYTM`

### Balance:
- `bal: Rs 5000`, `Available balance Rs 10000`

## Privacy & Security

### 🔒 **Local Processing**
- All SMS reading and parsing happens locally on your device
- No SMS data is sent to external servers
- Messages are processed in memory only

### 🛡️ **Permissions**
- Only requires READ_SMS permission
- No internet permission needed for SMS processing
- No data storage of SMS content

### 📱 **Android Requirements**
- Android API level 23+ (Android 6.0+)
- SMS permission granted by user

## Troubleshooting

### **No Transactions Found**
1. Check if SMS permission is granted
2. Ensure you have bank transaction SMS in your inbox
3. Check if SMS sender matches known bank patterns

### **Incorrect Amount Parsing**
- The app uses multiple regex patterns to detect amounts
- Some unusual SMS formats might not be recognized
- You can view the original SMS to verify

### **Missing Bank Transactions**
- The app looks for specific keywords in SMS
- Ensure SMS contains words like: debited, credited, bank, transaction
- Check if sender is a recognized bank code

### **Permission Issues**
- Go to Android Settings > Apps > Money Tracker > Permissions
- Enable SMS permission manually
- Restart the app after granting permission

## Technical Notes

### **Supported SMS Patterns**
- Indian banking SMS formats
- Multiple currency representations (Rs, INR, ₹)
- Various amount formats (with/without commas)
- Different date formats

### **Performance**
- Processes SMS messages efficiently
- Loads recent transactions first
- Pagination for large SMS volumes

### **Limitations**
- Depends on SMS format consistency
- Some bank-specific formats might need updates
- Regional SMS variations might not be recognized

## Future Enhancements

- Integration with existing transaction categories
- Automatic transaction creation from SMS
- Expense categorization based on merchant
- Balance tracking and reconciliation
- Export functionality for SMS transactions

---

**Note**: This feature is designed to help you track your financial transactions automatically. Always verify important transaction details with your bank statements. 