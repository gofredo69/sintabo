import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StatisticsPage extends StatefulWidget {
  final List<Map<String, dynamic>> expenses;
  final Map<String, Color> categoryColors;
  const StatisticsPage({super.key, required this.expenses, required this.categoryColors});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  String? _tappedCategory;

  @override
  Widget build(BuildContext context) {
    Map<String, Map<String, dynamic>> dataMap = {};
    
    for (var item in widget.expenses) {
      String cat = item['category'] ?? 'Other';
      double amt = (item['amount'] as num).toDouble();
      String colorHex = item['category_color'] ?? 'ff808080';

      if (!dataMap.containsKey(cat)) dataMap[cat] = {'amount': 0.0, 'category_color': colorHex};
      dataMap[cat]!['amount'] += amt;
    }

    // Calculate grand total once outside the mapping loop
    final double grandTotal = dataMap.values.fold(0.0, (sum, item) => sum + item['amount']);

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
            height: 300, // Increased height to prevent clipping
            child: dataMap.isEmpty 
                ? const Center(child: Text("No data for chart"))
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 50,
                        sectionsSpace: 4,
                        sections: dataMap.entries.toList().asMap().entries.map((entry) {
                          var data = entry.value;
                          String categoryName = data.key;
                          
                          return PieChartSectionData(
                            value: data.value['amount'],
                            title: '${(data.value['amount'] / grandTotal * 100).toInt()}%',
                            radius: _tappedCategory == data.key ? 80 : 70,
                            color: () {
                              String cat = data.key;
                              
                              // 1. Hardcoded Strict Palette (Ensures vibrancy)
                              if (cat == 'Food') return const Color(0xFFFF5252);
                              if (cat == 'Transport') return const Color(0xFF448AFF);
                              if (cat == 'Shopping') return const Color(0xFFFFD740);
                              if (cat == 'Bills') return const Color(0xFF7C4DFF);
                              
                              // 2. Dynamic Lookup for Custom Categories
                              try {
                                String hex = data.value['category_color'].toString().replaceAll('#', '');
                                if (hex.length == 6) hex = 'FF$hex'; 
                                return Color(int.parse(hex, radix: 16));
                              } catch (e) {
                                // 3. Fallback based on name length so segments remain distinct
                                return Colors.primaries[cat.length % Colors.primaries.length];
                              }
                            }(),
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
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
          ),
          const Divider(),
          // DRILL-DOWN LIST FOR SELECTED CATEGORY
          Expanded(
            child: _tappedCategory == null
                ? const Center(child: Text("Tap a category in the chart", style: TextStyle(color: Colors.grey)))
                : Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Details: $_tappedCategory", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const Icon(Icons.arrow_drop_down_circle_outlined, color: Color(0xFF6750A4)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: categoryExpenses.length,
                            itemBuilder: (ctx, i) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.grey.withOpacity(0.03),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF6750A4).withOpacity(0.1),
                                  child: const Icon(Icons.receipt_long, color: Color(0xFF6750A4), size: 18),
                                ),
                                title: Text(categoryExpenses[i]['description'] ?? "", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                subtitle: Text(categoryExpenses[i]['created_at'].split('T')[0], style: const TextStyle(fontSize: 11)),
                                trailing: Text("₱${categoryExpenses[i]['amount']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6750A4))),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}