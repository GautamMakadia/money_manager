import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  final userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard'), elevation: 0),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('expenses')
            .where('userId', isEqualTo: userId)
            .orderBy('date', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          final expenses = snapshot.data!.docs;
          double totalExpense = 0;
          Map<String, double> categoryTotals = {};

          for (var doc in expenses) {
            final data = doc.data() as Map<String, dynamic>;
            final amount = (data['amount'] ?? 0).toDouble();
            final category = data['category'] ?? 'Other';

            totalExpense += amount;
            categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: Colors.teal,
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Expenses', style: TextStyle(color: Colors.white70, fontSize: 16)),
                        SizedBox(height: 8),
                        Text(
                          '\$${totalExpense.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Text('Expense by Category', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                if (categoryTotals.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: categoryTotals.entries.map((e) {
                          return PieChartSectionData(
                            value: e.value,
                            title: '${e.key}\n\$${e.value.toStringAsFixed(0)}',
                            radius: 100,
                            titleStyle: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                SizedBox(height: 24),
                Text('Recent Transactions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ...expenses.take(5).map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(child: Icon(Icons.shopping_bag)),
                      title: Text(data['description'] ?? 'No description'),
                      subtitle: Text(data['category'] ?? 'Other'),
                      trailing: Text('\$${(data['amount'] ?? 0).toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}