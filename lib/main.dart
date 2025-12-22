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
  // 3. REAL-TIME DATA STREAM (Newest first)
  final Stream<List<Map<String, dynamic>>> _expensesStream = 
      Supabase.instance.client
          .from('expenses')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false); //

  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = 'Food';

  // 4. THE POP-UP FORM
  void _showAddExpenseSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, //
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, // Avoid keyboard
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
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: ['Food', 'Transport', 'Shopping', 'Bills', 'Other']
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
    );
  }

  // 5. SAVE LOGIC
  Future<void> _saveExpense(BuildContext context) async {
    if (_amountController.text.isEmpty) return;

    try {
      final deviceId = await getOrCreateDeviceId();
      await Supabase.instance.client.from('expenses').insert({
        'amount': double.parse(_amountController.text), //
        'category': _selectedCategory,
        'description': _descController.text,
        'device_id': deviceId,
      });

      if (mounted) {
        Navigator.pop(context);
        _amountController.clear();
        _descController.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense Added!')));
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
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
          
          // CALCULATE TOTAL SUM
          final total = expenses.fold<double>(
            0, (sum, item) => sum + (item['amount'] as num).toDouble(),
          );

          return Column(
            children: [
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
                child: expenses.isEmpty 
                  ? const Center(child: Text('No expenses yet!'))
                  : ListView.builder(
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final item = expenses[index];
                        return Card(
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
                        );
                      },
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