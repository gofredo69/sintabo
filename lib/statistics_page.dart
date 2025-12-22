import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StatisticsPage extends StatelessWidget {
  final List<Map<String, dynamic>> expenses;
  const StatisticsPage({super.key, required this.expenses});

  @override
  Widget build(BuildContext context) {
    // PREPARE DATA FOR PIE CHART
    Map<String, double> dataMap = {};
    for (var item in expenses) {
      String cat = item['category'] ?? 'Other';
      double amt = (item['amount'] as num).toDouble();
      dataMap[cat] = (dataMap[cat] ?? 0) + amt;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        // REMOVED: Download icon and CSV logic
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("Spending by Category", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            // PIE CHART
            SizedBox(
              height: 250,
              child: dataMap.isEmpty 
                ? const Center(child: Text("No data for chart"))
                : PieChart(
                    PieChartData(
                      sections: dataMap.entries.map((entry) {
                        return PieChartSectionData(
                          value: entry.value,
                          title: '${entry.key}\n₱${entry.value.toInt()}',
                          radius: 80,
                          titleStyle: const TextStyle(
                              fontSize: 10, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.white),
                          color: Colors.primaries[dataMap.keys.toList().indexOf(entry.key) % Colors.primaries.length],
                        );
                      }).toList(),
                    ),
                  ),
            ),
            const SizedBox(height: 30),
            const Divider(),
            // AI RANKING PLACEHOLDER
            const ListTile(
              leading: Icon(Icons.workspace_premium, color: Colors.amber),
              title: Text("Saving Rank: Calculating..."),
              subtitle: Text("AI will analyze your habits in the v1.0 release."),
            ),
          ],
        ),
      ),
    );
  }
}