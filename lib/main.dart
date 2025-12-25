import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart'; 
import 'calendar_page.dart';
import 'statistics_page.dart';
import 'category_budget_manager.dart';
import 'bill_registry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://cavcdfhnbuiruhywpuzj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNhdmNkZmhuYnVpcnVoeXdwdXpqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYzMzUzNTAsImV4cCI6MjA4MTkxMTM1MH0.89nL3gL1SLn15ZPwnpbOMRzLjdYBa6E3AWYgSq6KthU',
    headers: {
      'x-device-id': await getOrCreateDeviceId(), // Must match 'x-device-id' in SQL
    },
  );

  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('is_dark_mode') ?? false;
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  runApp(const SintaboApp());
}

Future<String> getOrCreateDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  // We use 'unique_device_id' everywhere now
  String? deviceId = prefs.getString('unique_device_id');
  
  if (deviceId == null || deviceId.isEmpty) {
    deviceId = Uuid().v4();
    await prefs.setString('unique_device_id', deviceId);
  }
  return deviceId;
}

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

class SintaboApp extends StatelessWidget {
  const SintaboApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Sintabo',
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFFE8DEF8),
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFFE8DEF8),
            brightness: Brightness.dark,
          ),
          themeMode: currentMode,
          home: const MainNavigation(),
        );
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  String? currentDeviceId;

  @override
  void initState() {
    super.initState();
    _loadId();
  }

  Future<void> _loadId() async {
    final id = await getOrCreateDeviceId();
    setState(() {
      currentDeviceId = id;
    });
  }

  void _showAddExpenseSheet(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final categories = prefs.getStringList('user_categories') ?? ['Food', 'Transport', 'Shopping', 'Bills', 'Other'];
    
    if (!context.mounted) return;

    final amountController = TextEditingController();
    final descController = TextEditingController();
    String cat = categories.first;
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
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setSS(() => cat = v!),
              ),
              TextField(controller: descController, decoration: const InputDecoration(labelText: "Description")),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () async {
                Navigator.pop(ctx);
                final deviceId = await getOrCreateDeviceId();
                
                // Combine selected date with current time to avoid 'Midnight Bug'
                final now = DateTime.now();
                final finalDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  now.hour,
                  now.minute,
                  now.second,
                );

                await Supabase.instance.client.from('expenses').insert({
                  'amount': double.parse(amountController.text),
                  'category': cat,
                  'description': descController.text,
                  'device_id': deviceId,
                  // Use local ISO string without timezone forcing
                  'created_at': finalDateTime.toIso8601String(),
                });
                setState(() {});
              }, child: const Text("Save")),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentDeviceId == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return StreamBuilder<List<Map<String, dynamic>>>(
      // FIXED: Defining stream here ensures it captures updates immediately
      stream: Supabase.instance.client
          .from('expenses')
          .stream(primaryKey: ['id'])
          .eq('device_id', currentDeviceId!)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final expenses = snapshot.data ?? [];
        
        final List<Widget> pages = [
          // Added a Key to the Dashboard so it rebuilds when the data count changes
          Dashboard(key: ValueKey(expenses.length), expenses: expenses),
          StatisticsPage(expenses: expenses),
          CalendarPage(expenses: expenses),
          ProfilePage(expenses: expenses),
        ];

        return Scaffold(
          body: pages[_selectedIndex],
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          floatingActionButton: FloatingActionButton(
            shape: const CircleBorder(),
            onPressed: () => _showAddExpenseSheet(context),
            child: const Icon(Icons.add, size: 30),
          ),
          bottomNavigationBar: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: Icon(Icons.home, color: _selectedIndex == 0 ? Colors.purple : Colors.grey),
                  onPressed: () => setState(() => _selectedIndex = 0),
                ),
                IconButton(
                  icon: Icon(Icons.bar_chart, color: _selectedIndex == 1 ? Colors.purple : Colors.grey),
                  onPressed: () => setState(() => _selectedIndex = 1),
                ),
                const SizedBox(width: 48),
                IconButton(
                  icon: Icon(Icons.calendar_month, color: _selectedIndex == 2 ? Colors.purple : Colors.grey),
                  onPressed: () => setState(() => _selectedIndex = 2),
                ),
                IconButton(
                  icon: Icon(Icons.person, color: _selectedIndex == 3 ? Colors.purple : Colors.grey),
                  onPressed: () => setState(() => _selectedIndex = 3),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class Dashboard extends StatefulWidget {
  final List<Map<String, dynamic>> expenses;
  const Dashboard({super.key, required this.expenses});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<String> _userCategories = ['Food', 'Transport', 'Shopping', 'Bills', 'Other'];
  String _selectedFilter = 'All';
  double _monthlyBudget = 10000.0;
  Map<String, double> _categoryBudgets = {};
  final Set<dynamic> _deletedIds = {};

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
      for (String cat in _userCategories) {
        _categoryBudgets[cat] = prefs.getDouble('budget_$cat') ?? 0.0;
      }
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('monthly_budget', _monthlyBudget);
    await prefs.setStringList('user_categories', _userCategories);
  }

  double _getAmountSpentInCategory(String category) {
    return widget.expenses
        .where((e) => e['category'] == category && !_deletedIds.contains(e['id']))
        .fold(0.0, (sum, e) => sum + (e['amount'] as num).toDouble());
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

  void _showExpenseDetails(BuildContext context, Map<String, dynamic> expense) {
    final DateTime date = DateTime.parse(expense['created_at']);
    final String formattedDate = "${date.month}/${date.day}/${date.year}";
    final String formattedTime = "${date.hour}:${date.minute.toString().padLeft(2, '0')}";

    final String rawDeviceId = expense['device_id']?.toString() ?? 'Unknown';
    final String deviceIdPreview = rawDeviceId.length >= 8 
        ? "${rawDeviceId.substring(0, 8)}..." 
        : rawDeviceId;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, 
                  height: 4, 
                  decoration: BoxDecoration(
                    color: Colors.grey[300], 
                    borderRadius: BorderRadius.circular(2)
                  )
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Transaction Detail", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
              const Divider(),
              _detailRow("Description", expense['description']?.toString() ?? 'No Description'),
              _detailRow("Amount", "₱${expense['amount']}"),
              _detailRow("Category", expense['category']?.toString() ?? 'Unknown'),
              _detailRow("Date", formattedDate),
              _detailRow("Time", formattedTime),
              _detailRow("Device ID", deviceIdPreview),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL: Calculate these values directly from the widget.expenses list.
    // This ensures that when the stream in MainNavigation pings, the UI updates instantly.
    final activeExpenses = widget.expenses.where((e) => !_deletedIds.contains(e['id'])).toList();
    
    final totalSpent = activeExpenses.fold<double>(
      0, (sum, item) => sum + (item['amount'] as num).toDouble()
    );

    final budgetPercent = (totalSpent / _monthlyBudget).clamp(0.0, 1.0);
    final budgetColor = budgetPercent > 0.9 ? Colors.red : Colors.green;

    final filtered = _selectedFilter == 'All' 
        ? activeExpenses 
        : activeExpenses.where((e) => e['category'] == _selectedFilter).toList();

    final filteredTotal = filtered.fold<double>(
      0, (sum, item) => sum + (item['amount'] as num).toDouble()
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Sintabo')),
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
          TotalSpentCard(amount: filteredTotal),
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
          if (_userCategories.any((cat) => (_categoryBudgets[cat] ?? 0) > 0))
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text("Active Envelopes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                ),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: _userCategories.where((cat) => (_categoryBudgets[cat] ?? 0) > 0).map((cat) {
                      final spent = _getAmountSpentInCategory(cat);
                      final limit = _categoryBudgets[cat]!;
                      final percent = (spent / limit).clamp(0.0, 1.0);
                      final isOver = spent > limit;
                      return Container(
                        width: 160,
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: themeNotifier.value == ThemeMode.dark ? Colors.grey[900] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isOver ? Colors.red.withOpacity(0.5) : Colors.transparent),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(cat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: percent,
                              color: isOver ? Colors.red : Colors.purple[200],
                              backgroundColor: Colors.grey[200],
                              minHeight: 4,
                            ),
                            const SizedBox(height: 4),
                            Text("₱${spent.toInt()} / ₱${limit.toInt()}", style: TextStyle(fontSize: 10, color: isOver ? Colors.red : Colors.grey)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadSettings();
                setState(() {}); 
              },
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final expense = filtered[i];
                  return Dismissible(
                    key: Key(expense['id'].toString()),
                    onDismissed: (dir) async {
                      final id = expense['id'];
                      setState(() => _deletedIds.add(id));
                      try {
                        await Supabase.instance.client.from('expenses').delete().match({'id': id});
                      } catch (e) {
                        if (mounted) setState(() => _deletedIds.remove(id));
                      }
                    },
                    background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.receipt_long, size: 20)),
                        title: Text(expense['description'] ?? 'No Description'),
                        subtitle: Text("${expense['category']} • ${expense['created_at'].toString().split('T')[0]}"),
                        trailing: Text("₱${expense['amount']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () => _showExpenseDetails(context, expense),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  final List<Map<String, dynamic>> expenses;
  const ProfilePage({super.key, required this.expenses});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile & Settings")),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFFE8DEF8),
                  child: Icon(Icons.person, size: 40, color: Colors.purple),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("User Activity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text("Managing your Sintabo data", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, currentMode, _) {
              return SwitchListTile(
                title: const Text("Dark Mode"),
                secondary: const Icon(Icons.dark_mode_outlined),
                value: currentMode == ThemeMode.dark,
                onChanged: (bool isDark) async {
                  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('is_dark_mode', isDark);
                },
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text("Category Budgets"),
            subtitle: const Text("Set limits for Food, Transport, etc."),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              final categories = prefs.getStringList('user_categories') ?? ['Food', 'Transport', 'Shopping', 'Bills', 'Other'];
              if (context.mounted) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (c) => CategoryBudgetManager(categories: categories)
                ));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text("Recurring Expenses"),
            subtitle: const Text("Manage subscriptions and bills"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              final categories = prefs.getStringList('user_categories') ?? ['Food', 'Transport', 'Shopping', 'Bills', 'Other'];
              if (context.mounted) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (c) => BillRegistry(
                    categories: categories, 
                    expenses: expenses, // Pass the live data from MainNavigation's stream
                  )
                ));
              }
            },
          ),
        ],
      ),
    );
  }
}

class TotalSpentCard extends StatelessWidget {
  final double amount;
  const TotalSpentCard({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8DEF8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text("Total Spent", style: TextStyle(color: Colors.black54, fontSize: 16)),
          Text(
            "₱${amount.toStringAsFixed(2)}",
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }
}