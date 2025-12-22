import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart'; 
import 'calendar_page.dart';
import 'statistics_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://cavcdfhnbuiruhywpuzj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNhdmNkZmhuYnVpcnVoeXdwdXpqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYzMzUzNTAsImV4cCI6MjA4MTkxMTM1MH0.89nL3gL1SLn15ZPwnpbOMRzLjdYBa6E3AWYgSq6KthU',
  );
  runApp(const SintaboApp());
}

Future<String> getOrCreateDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  String? deviceId = prefs.getString('device_id');
  if (deviceId == null) {
    deviceId = const Uuid().v4();
    await prefs.setString('device_id', deviceId);
  }
  return deviceId;
}

class SintaboApp extends StatelessWidget {
  const SintaboApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sintabo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFFE8DEF8)),
      home: const Dashboard(),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<String> _userCategories = ['Food', 'Transport', 'Shopping', 'Bills', 'Other'];
  String _selectedFilter = 'All';
  double _monthlyBudget = 10000.0;
  final _expensesStream = Supabase.instance.client.from('expenses').stream(primaryKey: ['id']).order('created_at', ascending: false);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _monthlyBudget = prefs.getDouble('monthly_budget') ?? 10000.0;
      _userCategories = prefs.getStringList('user_categories') ?? ['Food', 'Transport', 'Shopping', 'Bills', 'Other'];
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('monthly_budget', _monthlyBudget);
    await prefs.setStringList('user_categories', _userCategories);
  }

  void _editBudget() {
    final controller = TextEditingController(text: _monthlyBudget.toInt().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Monthly Budget"),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(prefixText: "₱ ")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: () {
            setState(() => _monthlyBudget = double.tryParse(controller.text) ?? _monthlyBudget);
            _saveSettings();
            Navigator.pop(ctx);
          }, child: const Text("Save")),
        ],
      ),
    );
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New Category"),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: "Category Name")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: () {
            if (controller.text.isNotEmpty) {
              setState(() => _userCategories.add(controller.text));
              _saveSettings();
              Navigator.pop(ctx);
            }
          }, child: const Text("Add")),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(String cat) {
    if (cat == 'Other' || cat == 'All') return; 
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Category?"),
        content: Text("All items in '$cat' will be moved to 'Other'."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await Supabase.instance.client.from('expenses').update({'category': 'Other'}).match({'category': cat});
              setState(() {
                _userCategories.remove(cat);
                if (_selectedFilter == cat) _selectedFilter = 'All';
              });
              await _saveSettings();
              if (mounted) Navigator.pop(ctx);
            }, 
            child: const Text("Delete")
          ),
        ],
      ),
    );
  }

  void _showAddExpenseSheet(BuildContext context) {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String cat = _userCategories.first;
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Add Expense", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Amount", prefixText: "₱ ")),
              ListTile(
                title: Text("Date: ${selectedDate.toLocal().toString().split(' ')[0]}"),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2101));
                  if (picked != null) setSS(() => selectedDate = picked);
                },
              ),
              DropdownButtonFormField<String>(
                value: cat,
                items: _userCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setSS(() => cat = v!),
              ),
              TextField(controller: descController, decoration: const InputDecoration(labelText: "Description")),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () async {
                final deviceId = await getOrCreateDeviceId();
                await Supabase.instance.client.from('expenses').insert({
                  'amount': double.parse(amountController.text),
                  'category': cat,
                  'description': descController.text,
                  'device_id': deviceId,
                  'created_at': selectedDate.toIso8601String(),
                });
                Navigator.pop(context);
              }, child: const Text("Save")),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _expensesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final expenses = snapshot.data!;
        
        final totalProjectSpent = expenses.fold<double>(0, (sum, item) => sum + (item['amount'] as num).toDouble());
        final budgetPercent = (totalProjectSpent / _monthlyBudget).clamp(0.0, 1.0);
        final budgetColor = budgetPercent > 0.9 ? Colors.red : Colors.green;

        final filtered = _selectedFilter == 'All' ? expenses : expenses.where((e) => e['category'] == _selectedFilter).toList();
        final filteredTotal = filtered.fold<double>(0, (sum, item) => sum + (item['amount'] as num).toDouble());

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sintabo'),
            actions: [
              IconButton(icon: const Icon(Icons.bar_chart), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => StatisticsPage(expenses: expenses)))),
              IconButton(icon: const Icon(Icons.calendar_month), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CalendarPage(expenses: expenses)))),
            ],
          ),
          body: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    ...['All', ..._userCategories].map((cat) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onLongPress: cat == 'All' ? null : () => _confirmDeleteCategory(cat),
                        child: ChoiceChip(label: Text(cat), selected: _selectedFilter == cat, onSelected: (s) => setState(() => _selectedFilter = cat)),
                      ),
                    )),
                    IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _showAddCategoryDialog),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: const Color(0xFFE8DEF8), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_selectedFilter == 'All' ? "Total Spent" : "Spent in $_selectedFilter", style: const TextStyle(fontSize: 18)),
                    Text("₱${filteredTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text("Monthly Budget: ₱${_monthlyBudget.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: _editBudget),
                      ],
                    ),
                    LinearProgressIndicator(value: budgetPercent, color: budgetColor, minHeight: 8, backgroundColor: Colors.grey[200]),
                    Text("${(budgetPercent * 100).toStringAsFixed(1)}% of limit spent", style: TextStyle(color: budgetColor, fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    setState(() {}); // Pull-to-refresh functional
                    await Future.delayed(const Duration(seconds: 1));
                  },
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => Dismissible(
                      key: Key(filtered[i]['id'].toString()),
                      // FIXED: Permanently deletes from Supabase
                      onDismissed: (dir) async {
                        final id = filtered[i]['id'];
                        await Supabase.instance.client.from('expenses').delete().match({'id': id});
                      },
                      background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: Text(filtered[i]['description'] ?? ""),
                          subtitle: Text("${filtered[i]['category']} • ${filtered[i]['created_at'].split('T')[0]}"),
                          trailing: Text("₱${filtered[i]['amount']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(onPressed: () => _showAddExpenseSheet(context), child: const Icon(Icons.add)),
        );
      },
    );
  }
}