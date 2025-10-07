
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  final userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Dashboard'), elevation: 0),
        body: Center(
            child: Text('No user session found. Please sign in again.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Dashboard'), elevation: 0),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('expenses')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Failed to load dashboard: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          final expenses = List<
              QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs)
            ..sort((a, b) {
              final bDate = _parseDate(b.data()['date']);
              final aDate = _parseDate(a.data()['date']);
              return bDate.compareTo(aDate);
            });
          final recentExpenses = expenses.take(50).toList();

          double totalExpense = 0;
          final Map<String, double> categoryTotals = {};

          for (var doc in recentExpenses) {
            final data = doc.data();
            final amount = _parseAmount(data['amount']);
            final category = data['category'] as String? ?? 'Other';

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
                        Text('Total Expenses', style: TextStyle(
                            color: Colors.white70, fontSize: 16)),
                        SizedBox(height: 8),
                        Text(
                          '\$${totalExpense.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Text('Expense by Category', style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
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
                            titleStyle: TextStyle(fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                SizedBox(height: 24),
                Text('Recent Transactions', style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ...recentExpenses.take(5).map((doc) {
                  final data = doc.data();
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(child: Icon(Icons.shopping_bag)),
                      title: Text(data['description'] ?? 'No description'),
                      subtitle: Text(data['category'] ?? 'Other'),
                      trailing: Text('\$${_parseAmount(data['amount'])
                          .toStringAsFixed(2)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
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

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}