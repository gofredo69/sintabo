import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. INITIALIZE SUPABASE
  await Supabase.initialize(
    url: 'https://cavcdfhnbuiruhywpuzj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNhdmNkZmhuYnVpcnVoeXdwdXpqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYzMzUzNTAsImV4cCI6MjA4MTkxMTM1MH0.89nL3gL1SLn15ZPwnpbOMRzLjdYBa6E3AWYgSq6KthU',
  );

  runApp(const SintaboApp());
}

// 2. HELPER FUNCTION: DEVICE ID
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
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
  String _selectedFilter = 'All'; // Track the active filter

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  // 3. REAL-TIME DATA STREAM (Newest first)
  final Stream<List<Map<String, dynamic>>> _expensesStream = 
      Supabase.instance.client
          .from('expenses')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false); //

  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = 'Food';
  DateTime _selectedDate = DateTime.now(); // Track the chosen date

  void _showAddExpenseSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder( // Use StatefulBuilder to update the date inside the sheet
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add New Expense', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount', prefixText: '₱ '),
              ),
              // DATE PICKER BUTTON
              ListTile(
                title: Text("Date: ${_selectedDate.toLocal()}".split(' ')[0]),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null) {
                    setSheetState(() => _selectedDate = picked);
                  }
                },
              ),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: _userCategories
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              TextField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _saveExpense(context),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: const Text('Save Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveExpense(BuildContext context) async {
    if (_amountController.text.isEmpty) return;
    try {
      final deviceId = await getOrCreateDeviceId();
      await Supabase.instance.client.from('expenses').insert({
        'amount': double.parse(_amountController.text),
        'category': _selectedCategory,
        'description': _descController.text,
        'device_id': deviceId,
        'created_at': _selectedDate.toIso8601String(), // Save the picked date!
      });
      if (mounted) {
        Navigator.pop(context);
        _amountController.clear();
        _descController.clear();
        _selectedDate = DateTime.now(); // Reset to today
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense Added!')));
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'e.g. Health')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _userCategories.add(controller.text); // Update the UI instantly
                });
                await _saveCategoriesToDisk();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(String category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Remove "$category" from your list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              setState(() {
                _userCategories.remove(category); // 1. Remove from local list
                if (_selectedFilter == category) _selectedFilter = 'All'; // 2. Reset filter
              });
              
              // 3. IMPORTANT: Save the new list to SharedPreferences!
              await _saveCategoriesToDisk(); 
              
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedCategories = prefs.getStringList('user_categories');
    if (savedCategories != null) {
      setState(() => _userCategories = savedCategories);
    }
  }

  Future<void> _saveCategoriesToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('user_categories', _userCategories);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sintabo AI')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _expensesStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final expenses = snapshot.data!;

          // FILTER THE LIST BASED ON SELECTION
          final filteredExpenses = _selectedFilter == 'All' 
              ? expenses 
              : expenses.where((item) {
                  if (_selectedFilter == 'Other') {
                    // Show 'Other' AND anything that doesn't match current categories
                    return item['category'] == 'Other' || !_userCategories.contains(item['category']);
                  }
                  return item['category'] == _selectedFilter;
                }).toList();

          // IMPORTANT: Update your Total calculation to use 'filteredExpenses'
          final total = filteredExpenses.fold<double>(
            0, (sum, item) => sum + (item['amount'] as num).toDouble(),
          );

          return Column(
            children: [
              // ADD FILTER CHIPS ROW
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // 1. The existing category chips
                    ...['All', ..._userCategories].map((category) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          // Detect Long Press for deletion
                          onLongPress: category == 'All' ? null : () => _confirmDeleteCategory(category),
                          child: ChoiceChip(
                            label: Text(category),
                            selected: _selectedFilter == category,
                            onSelected: (selected) => setState(() => _selectedFilter = category),
                          ),
                        ),
                      );
                    }),
                    // 2. The NEW "Add Category" button
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => _showAddCategoryDialog(),
                    ),
                  ],
                ),
              ),

              // TOTAL SUMMARY CARD
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Spent', style: TextStyle(fontSize: 18)),
                      Text(
                        '₱${total.toStringAsFixed(2)}', 
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              
              // THE LIST VIEW (Expanded to fill the rest of the screen)
              Expanded(
                child: filteredExpenses.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text('No expenses recorded yet.', style: TextStyle(color: Colors.grey)),
                        ],
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          // Manually trigger a refresh of the stream
                          setState(() {}); 
                             await Future.delayed(const Duration(seconds: 1));
                        },
                        child: ListView.builder(
                          itemCount: filteredExpenses.length,
                          itemBuilder: (context, index) {
                            final item = filteredExpenses[index];
                            return Dismissible(
                              key: Key(item['id'].toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (direction) async {
                                await Supabase.instance.client
                                    .from('expenses')
                                    .delete()
                                    .match({'id': item['id']});
                              },
                              child: Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: ListTile(
                                  leading: const Icon(Icons.receipt_long),
                                  title: Text(item['description'] ?? 'No Description'),
                                  subtitle: Text(item['category']),
                                  trailing: Text(
                                    '₱${item['amount']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpenseSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}