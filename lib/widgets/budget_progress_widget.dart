import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BudgetProgressWidget extends StatelessWidget {
  final double totalBudget;
  final double spentAmount;

  const BudgetProgressWidget({
    Key? key,
    required this.totalBudget,
    required this.spentAmount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double leftAmount = totalBudget - spentAmount;
    final double progressPercentage = spentAmount / totalBudget;
    
    return Container(
      width: 350,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: Offset(0, 6),
            blurRadius: 60,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row with amount left and arrow
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\$${_formatAmount(leftAmount)} left',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  height: 1.3,
                ),
              ),
              Icon(
                Icons.arrow_forward,
                size: 16,
                color: Color(0xFF181818), // Dark gray from design
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          // Progress bar
          Container(
            height: 12,
            child: Stack(
              children: [
                // Background bar
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Color(0xFFF7F8F9), // Light gray background
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                
                // Progress fill
                Container(
                  width: (310 * progressPercentage).clamp(0.0, 310.0),
                  height: 12,
                  decoration: BoxDecoration(
                    color: Color(0xFF7340FF), // Purple color from design
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF7340FF).withOpacity(0.3),
                        offset: Offset(0, 3),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
                
                // Progress indicator line
                Positioned(
                  left: (310 * 0.93).clamp(0.0, 298.0), // 93% position like in design
                  top: 0,
                  child: Container(
                    width: 2,
                    height: 12,
                    color: Color(0xFFDCDDDD), // Light gray line
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 12),
          
          // Bottom text
          Text(
            '\$${_formatAmount(spentAmount)} of \$${_formatAmount(totalBudget)} spent',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Color(0xFF929292), // Gray color from design
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(2)}K';
    }
    return amount.toStringAsFixed(2);
  }
} 