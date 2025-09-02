import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io' show File;
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:html' as html; // Only used for web

void main() {
  runApp(const ExpenseApp());
}

class ExpenseApp extends StatefulWidget {
  const ExpenseApp({super.key});

  @override
  State<ExpenseApp> createState() => _ExpenseAppState();
}

class _ExpenseAppState extends State<ExpenseApp> {
  bool _isDark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _isDark ? ThemeData.dark() : ThemeData.light(),
      home: ExpenseHomePage(
        isDark: _isDark,
        toggleTheme: () {
          setState(() {
            _isDark = !_isDark;
          });
        },
      ),
    );
  }
}

class ExpenseHomePage extends StatefulWidget {
  final bool isDark;
  final VoidCallback toggleTheme;

  const ExpenseHomePage({super.key, required this.isDark, required this.toggleTheme});

  @override
  State<ExpenseHomePage> createState() => _ExpenseHomePageState();
}

class _ExpenseHomePageState extends State<ExpenseHomePage> {
  final List<Map<String, dynamic>> _transactions = [];
  int _selectedIndex = 0;

  final Map<String, Color> categoryColors = {
    "Food": Colors.green,
    "Transport": Colors.orange,
    "Shopping": Colors.blue,
    "Bills": Colors.red,
    "Other": Colors.grey,
    "Salary": Colors.purple,
  };

  void _addTransaction(String amount, String category, DateTime date, String type, {bool recurring = false}) {
    setState(() {
      _transactions.add({
        "amount": amount,
        "category": category,
        "date": date,
        "type": type,
        "recurring": recurring,
      });
    });
  }

  double get totalIncome => _transactions
      .where((t) => t["type"] == "Income")
      .fold(0.0, (sum, t) => sum + double.parse(t["amount"]));

  double get totalExpense => _transactions
      .where((t) => t["type"] == "Expense")
      .fold(0.0, (sum, t) => sum + double.parse(t["amount"]));

  double get balance => totalIncome - totalExpense;

  Map<String, double> getCategoryTotals() {
    Map<String, double> totals = {};
    for (var t in _transactions.where((t) => t["type"] == "Expense")) {
      final category = t["category"];
      final amount = double.parse(t["amount"]);
      totals[category] = (totals[category] ?? 0) + amount;
    }
    return totals;
  }

  Map<String, double> getDailyTotals() {
    Map<String, double> totals = {};
    for (var t in _transactions.where((t) => t["type"] == "Expense")) {
      final dateKey = DateFormat('MM/dd').format(t["date"]);
      final amount = double.parse(t["amount"]);
      totals[dateKey] = (totals[dateKey] ?? 0) + amount;
    }
    return totals;
  }

  Future<void> _exportToCSV() async {
    String csv = "Amount,Category,Date,Type,Recurring\n";
    for (var t in _transactions) {
      csv += "${t['amount']},${t['category']},${DateFormat.yMd().format(t['date'])},${t['type']},${t['recurring']}\n";
    }

    if (kIsWeb) {
      // Web download
      final bytes = utf8.encode(csv);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "transactions.csv")
        ..click();
      html.Url.revokeObjectUrl(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Download started")));
      }
    } else {
      // Mobile/desktop save
      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/transactions.csv";
      final file = File(path);
      await file.writeAsString(csv);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Exported to $path")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboard(),
      _buildAnalytics(),
      AddTransactionPage(onAdd: _addTransaction),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Expense Manager"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportToCSV,
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Dashboard"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Analytics"),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: "Add"),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _summaryCard("Income", totalIncome, Colors.green),
              _summaryCard("Expense", totalExpense, Colors.red),
              _summaryCard("Balance", balance, Colors.blue),
            ],
          ),
        ),
        Expanded(
          child: _transactions.isEmpty
              ? const Center(child: Text("No transactions yet."))
              : ListView.builder(
            itemCount: _transactions.length,
            itemBuilder: (context, i) {
              final t = _transactions[i];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (categoryColors[t["category"]] ?? Colors.grey).withOpacity(0.7),
                    child: Icon(
                      t["type"] == "Income" ? Icons.arrow_downward : Icons.arrow_upward,
                      color: Colors.white,
                    ),
                  ),
                  title: Text("${t['type']}: ₹${t['amount']}"),
                  subtitle: Text("${t['category']} • ${DateFormat.yMMMd().format(t['date'])}"),
                  trailing: t["recurring"] ? const Icon(Icons.repeat, color: Colors.deepPurple) : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnalytics() {
    final totals = getCategoryTotals();
    final dailyTotals = getDailyTotals();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text("Category Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: totals.isEmpty
                ? const Center(child: Text("No expense data"))
                : PieChart(
              PieChartData(
                sections: totals.entries.map((e) {
                  return PieChartSectionData(
                    value: e.value,
                    title: e.key,
                    color: categoryColors[e.key] ?? Colors.grey,
                    radius: 70,
                    titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 30,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text("Daily Spending (Bar Chart)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: dailyTotals.isEmpty
                ? const Center(child: Text("No daily data"))
                : BarChart(
              BarChartData(
                borderData: FlBorderData(show: false),
                barGroups: dailyTotals.entries.map((e) {
                  return BarChartGroupData(
                    x: dailyTotals.keys.toList().indexOf(e.key),
                    barRods: [
                      BarChartRodData(
                        toY: e.value,
                        color: Colors.blue,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < 0 || value.toInt() >= dailyTotals.length) return Container();
                        final label = dailyTotals.keys.toList()[value.toInt()];
                        return Text(label, style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, double value, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text("₹${value.toStringAsFixed(2)}", style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class AddTransactionPage extends StatefulWidget {
  final Function(String, String, DateTime, String, {bool recurring}) onAdd;

  const AddTransactionPage({super.key, required this.onAdd});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final TextEditingController _amountController = TextEditingController();
  String _type = "Expense";
  String _category = "Food";
  DateTime _date = DateTime.now();
  bool _recurring = false;

  final List<String> _categories = ["Food", "Transport", "Shopping", "Bills", "Other", "Salary"];

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text("Add Transaction", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Amount", prefixIcon: Icon(Icons.currency_rupee)),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: _type,
            items: ["Income", "Expense"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => _type = v!),
            decoration: const InputDecoration(labelText: "Type"),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: _category,
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _category = v!),
            decoration: const InputDecoration(labelText: "Category"),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: Text("Date: ${DateFormat.yMMMd().format(_date)}")),
              IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
            ],
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text("Recurring"),
            value: _recurring,
            onChanged: (v) => setState(() => _recurring = v),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text("Save"),
            onPressed: () {
              if (_amountController.text.isNotEmpty) {
                widget.onAdd(_amountController.text, _category, _date, _type, recurring: _recurring);
                setState(() {
                  _amountController.clear();
                  _category = "Food";
                  _type = "Expense";
                  _recurring = false;
                  _date = DateTime.now();
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transaction added!")));
              }
            },
          ),
        ],
      ),
    );
  }
}
