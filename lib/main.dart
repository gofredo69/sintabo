import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. INITIALIZE SUPABASE
  await Supabase.initialize(
    url: 'https://cavcdfhnbuiruhywpuzj.supabase.co', // PASTE YOUR URL HERE
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNhdmNkZmhuYnVpcnVoeXdwdXpqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYzMzUzNTAsImV4cCI6MjA4MTkxMTM1MH0.89nL3gL1SLn15ZPwnpbOMRzLjdYBa6E3AWYgSq6KthU',              // PASTE YOUR ANON KEY HERE
  );

  runApp(const SintaboApp());
}

// 2. HELPER FUNCTION: GET OR CREATE DEVICE ID
// This uniquely identifies this phone in your database
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

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  // 3. STEP 6 LOGIC: SAVE TO DATABASE
  Future<void> addTestExpense(BuildContext context) async {
    try {
      final deviceId = await getOrCreateDeviceId();
      
      await Supabase.instance.client.from('expenses').insert({
        'amount': 50.00,
        'category': 'Food',
        'description': 'Test Dinner via Sintabo',
        'device_id': deviceId,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense saved to Supabase!')),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sintabo AI')),
      body: const Center(
        child: Text('Press the (+) to test your database connection'),
      ),
      // 4. THE TEST BUTTON
      floatingActionButton: FloatingActionButton(
        onPressed: () => addTestExpense(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}