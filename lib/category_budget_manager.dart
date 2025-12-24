import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryBudgetManager extends StatefulWidget {
  final List<String> categories;
  const CategoryBudgetManager({super.key, required this.categories});

  @override
  State<CategoryBudgetManager> createState() => _CategoryBudgetManagerState();
}

class _CategoryBudgetManagerState extends State<CategoryBudgetManager> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (var cat in widget.categories) {
      _controllers[cat] = TextEditingController();
      _loadExistingBudget(cat);
    }
  }

  Future<void> _loadExistingBudget(String cat) async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getDouble('budget_$cat') ?? 0.0;
    if (val > 0) _controllers[cat]!.text = val.toInt().toString();
  }

  Future<void> _saveAllBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    for (var entry in _controllers.entries) {
      final val = double.tryParse(entry.value.text) ?? 0.0;
      await prefs.setDouble('budget_${entry.key}', val);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Category Allocations")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Set individual spending limits for your envelopes:", 
            style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 20),
          ...widget.categories.map((cat) => ListTile(
            title: Text(cat),
            trailing: SizedBox(width: 120, child: TextField(
              controller: _controllers[cat],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(prefixText: "₱ ", border: OutlineInputBorder()),
            )),
          )),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _saveAllBudgets, 
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            child: const Text("Save Envelope Limits"),
          ),
        ],
      ),
    );
  }
}