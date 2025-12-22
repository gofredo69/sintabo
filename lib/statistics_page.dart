import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StatisticsPage extends StatefulWidget {
  final List<Map<String, dynamic>> expenses;
  const StatisticsPage({super.key, required this.expenses});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  String? _tappedCategory;

  @override
  Widget build(BuildContext context) {
    Map<String, double> dataMap = {};
    for (var item in widget.expenses) {
      String cat = item['category'] ?? 'Other';
      double amt = (item['amount'] as num).toDouble();
      dataMap[cat] = (dataMap[cat] ?? 0) + amt;
    }

    final categoryExpenses = _tappedCategory == null 
        ? [] 
        : widget.expenses.where((e) => e['category'] == _tappedCategory).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics'), centerTitle: true),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text("Spending by Category", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          // DONUT CHART WITH TOUCH INTERACTION
          SizedBox(
            height: 250,
            child: dataMap.isEmpty 
                ? const Center(child: Text("No data for chart"))
                : PieChart(
                    PieChartData(
                      centerSpaceRadius: 50, // Donut look
                      sections: dataMap.entries.toList().asMap().entries.map((entry) {
                        int idx = entry.key;
                        var data = entry.value;
                        return PieChartSectionData(
                          value: data.value,
                          title: '${data.key}\n₱${data.value.toInt()}',
                          radius: 70,
                          color: Colors.primaries[idx % Colors.primaries.length],
                          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        );
                      }).toList(),
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          if (!event.isInterestedForInteractions || 
                              pieTouchResponse == null || 
                              pieTouchResponse.touchedSection == null) return;
                          setState(() {
                            final index = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            if (index >= 0) _tappedCategory = dataMap.keys.elementAt(index);
                          });
                        },
                      ),
                    ),
                  ),
          ),
          const Divider(),
          // DRILL-DOWN LIST FOR SELECTED CATEGORY
          Expanded(
            child: _tappedCategory == null
                ? const Center(child: Text("Tap a category in the chart to see details"))
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text("Details for: $_tappedCategory", style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: categoryExpenses.length,
                          itemBuilder: (ctx, i) => ListTile(
                            leading: const Icon(Icons.receipt_long),
                            title: Text(categoryExpenses[i]['description'] ?? ""),
                            subtitle: Text(categoryExpenses[i]['created_at'].split('T')[0]),
                            trailing: Text("₱${categoryExpenses[i]['amount']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}