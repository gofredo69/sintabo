import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

<<<<<<< HEAD
<<<<<<< HEAD
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
    Map<String, double> totals = {};
    for (var e in widget.expenses) {
      totals[e['category']] = (totals[e['category']] ?? 0) + (e['amount'] as num).toDouble();
    }
    final colors = [Colors.redAccent, Colors.pink, Colors.purple, Colors.orange, Colors.blue];
    final categoryExpenses = _tappedCategory == null 
        ? [] 
        : widget.expenses.where((e) => e['category'] == _tappedCategory).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Statistics"), centerTitle: true),
      body: Column(
        children: [
          const Padding(padding: EdgeInsets.all(20), child: Text("Spending by Category", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          SizedBox(
            height: 250,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 50,
                sections: totals.entries.toList().asMap().entries.map((entry) => PieChartSectionData(
                  color: colors[entry.key % colors.length],
                  value: entry.value.value,
                  title: "${entry.value.key}\n₱${entry.value.value.toInt()}",
                  radius: 70,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                )).toList(),
                pieTouchData: PieTouchData(
                  touchCallback: (event, res) {
                    if (res != null && res.touchedSection != null) {
                      setState(() => _tappedCategory = totals.keys.elementAt(res.touchedSection!.touchedSectionIndex));
                    }
                  },
                ),
              ),
            ),
          ),
          if (_tappedCategory != null) Expanded(
            child: ListView.builder(
              itemCount: categoryExpenses.length,
              itemBuilder: (ctx, i) => ListTile(
                title: Text(categoryExpenses[i]['description'] ?? ""),
                subtitle: Text(categoryExpenses[i]['created_at'].split('T')[0]),
                trailing: Text("₱${categoryExpenses[i]['amount']}"),
              ),
            ),
          ),
        ],
=======
=======
>>>>>>> d7f56cda037f7eb3aa450e6896e81a758cde87f1
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
<<<<<<< HEAD
>>>>>>> d7f56cda037f7eb3aa450e6896e81a758cde87f1
=======
>>>>>>> d7f56cda037f7eb3aa450e6896e81a758cde87f1
      ),
    );
  }
}