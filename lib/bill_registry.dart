import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // Required for encoding the bill list
import 'package:uuid/uuid.dart';

Future<String> getOrCreateDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  // Ensure this key name is IDENTICAL in both files
  String? deviceId = prefs.getString('unique_device_id');
  
  if (deviceId == null || deviceId.isEmpty) {
    deviceId = Uuid().v4();
    await prefs.setString('unique_device_id', deviceId);
  }
  return deviceId;
}

class BillRegistry extends StatefulWidget {
  final List<String> categories;
  final List<Map<String, dynamic>> expenses;
  const BillRegistry({super.key, required this.categories, required this.expenses});

  @override
  State<BillRegistry> createState() => _BillRegistryState();
}

class _BillRegistryState extends State<BillRegistry> {
  List<Map<String, dynamic>> _bills = [];

  @override
  void initState() {
    super.initState();
    _loadBills(); // Load saved bills on startup
  }

  // SAVE/LOAD LOGIC: Keeps your registry persistent on the device
  Future<void> _saveBills() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_bills', jsonEncode(_bills));
  }

  Future<void> _loadBills() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('saved_bills');
    if (savedData != null) {
      setState(() => _bills = List<Map<String, dynamic>>.from(jsonDecode(savedData)));
    }
  }

  // ADD BILL DIALOG
  void _showAddBillDialog() {
    final nameController = TextEditingController();
    final amtController = TextEditingController();
    final dueController = TextEditingController();
    String selectedCat = widget.categories.first;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New Recurring Bill"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Bill Name (e.g. Netflix)")),
            TextField(controller: amtController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Amount", prefixText: "₱ ")),
            TextField(controller: dueController, decoration: const InputDecoration(labelText: "Due Date (e.g. 25th)")),
            DropdownButtonFormField<String>(
              value: selectedCat,
              items: widget.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => selectedCat = v!,
              decoration: const InputDecoration(labelText: "Category"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: () {
            setState(() {
              _bills.add({
                'name': nameController.text,
                'amount': double.tryParse(amtController.text) ?? 0.0,
                'category': selectedCat,
                'due': dueController.text,
              });
            });
            _saveBills();
            Navigator.pop(ctx);
          }, child: const Text("Add")),
        ],
      ),
    );
  }

  bool _isBillPaid(String billName) {
    final now = DateTime.now();
    // This searches the live expenses list for a match this month
    return widget.expenses.any((e) {
      final date = DateTime.parse(e['created_at']);
      return e['description'] == "Paid: $billName" && 
             date.month == now.month && 
             date.year == now.year;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Subscriptions & Bills")),
      body: _bills.isEmpty 
        ? const Center(child: Text("No recurring bills added yet."))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _bills.length,
            itemBuilder: (ctx, i) {
              final bill = _bills[i];
              // 1. Check the live database list for this specific bill
              final bool isPaid = _isBillPaid(bill['name']);

              return Dismissible(
                key: Key(bill['name'] + i.toString()),
                direction: DismissDirection.endToStart,
                onDismissed: (dir) {
                  setState(() => _bills.removeAt(i));
                  _saveBills(); // Save the list after deletion
                },
                background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: Text(bill['name']),
                    subtitle: Text("Due: ${bill['due']} • ₱${bill['amount']}"),
                    // 2. Use the 'isPaid' variable to decide what to show
                    trailing: isPaid 
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            Text("Paid", style: TextStyle(color: Colors.green, fontSize: 12)),
                          ],
                        )
                      : ElevatedButton(
                          onPressed: () => _markAsPaid(bill),
                          child: const Text("Pay"),
                        ),
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBillDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _markAsPaid(Map<String, dynamic> bill) async {
    final deviceId = await getOrCreateDeviceId();
    final now = DateTime.now();

    try {
      // 1. Perform the database insert
      await Supabase.instance.client.from('expenses').insert({
        'amount': bill['amount'],
        'category': bill['category'] ?? 'Bills',
        'description': "Paid: ${bill['name']}",
        'device_id': deviceId,
        'created_at': now.toUtc().toIso8601String(), 
      }).setHeader('x-device-id', deviceId);

      // 2. CRITICAL: Manually add the new payment to the local list temporarily
      // This forces the 'Paid' check to pass immediately without waiting for the Navigator to pop.
      setState(() {
        widget.expenses.add({
          'description': "Paid: ${bill['name']}",
          'created_at': now.toUtc().toIso8601String(),
          'amount': bill['amount'],
          'category': bill['category'],
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment Successful!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Payment Logic Error: $e");
    }
  }
}