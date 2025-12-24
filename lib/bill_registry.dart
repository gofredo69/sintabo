import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // Required for encoding the bill list
import 'package:uuid/uuid.dart';

Future<String> getOrCreateDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  String? deviceId = prefs.getString('unique_device_id');
  if (deviceId == null || deviceId.isEmpty) {
    deviceId = Uuid().v4();
    await prefs.setString('unique_device_id', deviceId);
  }
  return deviceId;
}

class BillRegistry extends StatefulWidget {
  final List<String> categories;
  const BillRegistry({super.key, required this.categories});

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
                    trailing: ElevatedButton(
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

    try {
      await Supabase.instance.client
          .from('expenses')
          .insert({
            'amount': bill['amount'],
            'category': bill['category'] ?? 'Bills',
            'description': "Paid: ${bill['name']}",
            'device_id': deviceId, 
            'created_at': DateTime.now().toIso8601String(),
          })
          .setHeader('x-device-id', deviceId);
    
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment Successful!"), backgroundColor: Colors.green),
        );
        
        // This is important: Pop with a result to notify the parent to refresh if needed
        Navigator.pop(context, true); 
      }
    } catch (e) {
      debugPrint("Payment Logic Error: $e");
    }
  }
}