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
  
  // 1. Initialize Supabase as usual
  await Supabase.initialize(
    url: 'https://cavcdfhnbuiruhywpuzj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNhdmNkZmhuYnVpcnVoeXdwdXpqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYzMzUzNTAsImV4cCI6MjA4MTkxMTM1MH0.89nL3gL1SLn15ZPwnpbOMRzLjdYBa6E3AWYgSq6KthU',
  );

  // 2. Load the theme preference from storage
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('is_dark_mode') ?? false; // Default to Light if not set
  
  // 3. Set the initial value of our global notifier
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  runApp(const SintaboApp());
}

Future<String> getOrCreateDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  // 1. Check if this specific phone already has an ID
  String? deviceId = prefs.getString('unique_device_id');

  // 2. If it's a new phone (or fresh install), create a brand NEW unique ID
  if (deviceId == null || deviceId.isEmpty) {
    deviceId = Uuid().v4(); // This generates a totally different string every time
    await prefs.setString('unique_device_id', deviceId);
  }
  return deviceId;
}

// Ensure this is outside any class at the top of main.dart
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

class SintaboApp extends StatelessWidget {
  const SintaboApp({super.key});

  @override
  Widget build(BuildContext context) {
    // This is the "brain" that listens to your toggle
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
          themeMode: currentMode, // This must be linked to currentMode
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

  void _showAddExpenseSheet(BuildContext context) async {
    // Load categories dynamically so the global FAB always has the latest list
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
                final deviceId = await getOrCreateDeviceId();
                await Supabase.instance.client.from('expenses').insert({
                  'amount': double.parse(amountController.text),
                  'category': cat,
                  'description': descController.text,
                  'device_id': deviceId,
                  'created_at': selectedDate.toIso8601String(),
                });
                if (context.mounted) Navigator.pop(context);
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
      stream: Supabase.instance.client.from('expenses').stream(primaryKey: ['id']).order('created_at', ascending: false),
      builder: (context, snapshot) {
        final expenses = snapshot.data ?? [];
        final List<Widget> pages = [
          Dashboard(expenses: expenses),
          StatisticsPage(expenses: expenses),
          CalendarPage(expenses: expenses),
          const ProfilePage(),
        ];

        return Scaffold(
          body: pages[_selectedIndex],
          // 1. Position the button in the center of the bar
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          floatingActionButton: FloatingActionButton(
            shape: const CircleBorder(), // Round shape for OCR prep
            onPressed: () => _showAddExpenseSheet(context),
            child: const Icon(Icons.add, size: 30),
          ),
          // 2. Use BottomAppBar for the "Notch" design
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
                const SizedBox(width: 48), // Spacer for the FAB in the middle
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
  Map<String, double> _categoryBudgets = {}; // Stores limits like {'Food': 3000}

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
      
      // Load individual category budgets using a dynamic key
      for (String cat in _userCategories) {
        _categoryBudgets[cat] = prefs.getDouble('budget_$cat') ?? 0.0;
      }
    });
  }

  // Helper to calculate spending for a specific envelope
  double _getAmountSpentInCategory(String category) {
    return widget.expenses
        .where((e) => e['category'] == category)
        .fold(0.0, (sum, e) => sum + (e['amount'] as num).toDouble());
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

  void _showExpenseDetails(BuildContext context, Map<String, dynamic> expense) {
    // Parse the timestamp for a cleaner UI
    final DateTime date = DateTime.parse(expense['created_at']);
    final String formattedDate = "${date.month}/${date.day}/${date.year}";
    final String formattedTime = "${date.hour}:${date.minute.toString().padLeft(2, '0')}";

    // Safety check for device_id to prevent crashes
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
              // REMOVED 'const' from here because the style or content might be dynamic
              Text(
                "Transaction Detail", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
              const Divider(),
              // These rows are dynamic and MUST NOT have 'const'
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

  // Helper widget for clean rows
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
    final expenses = widget.expenses;

        final totalProjectSpent = expenses.fold<double>(0, (sum, item) => sum + (item['amount'] as num).toDouble());
        final budgetPercent = (totalProjectSpent / _monthlyBudget).clamp(0.0, 1.0);
        final budgetColor = budgetPercent > 0.9 ? Colors.red : Colors.green;

        final filtered = _selectedFilter == 'All' ? expenses : expenses.where((e) => e['category'] == _selectedFilter).toList();
        final filteredTotal = filtered.fold<double>(0, (sum, item) => sum + (item['amount'] as num).toDouble());

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sintabo'),
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
              // FORCE VISIBILITY FIX
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8DEF8), // The light purple background from your screenshot
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text("Total Spent", style: TextStyle(color: Colors.black54, fontSize: 16)),
                    Text(
                      "₱${filteredTotal.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        // We use absolute black here to ensure it never "blends" in
                        color: Colors.black, 
                        letterSpacing: -1,
                      ),
                    ),
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
              // COMPACT HORIZONTAL ENVELOPES
              if (_userCategories.any((cat) => (_categoryBudgets[cat] ?? 0) > 0))
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text("Active Envelopes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                    ),
                    SizedBox(
                      height: 100, // Fixed height to keep the UI stable
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
                                Text("₱${spent.toInt()} / ₱${limit.toInt()}", 
                                  style: TextStyle(fontSize: 10, color: isOver ? Colors.red : Colors.grey)),
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
                    await _loadSettings(); // Reload budgets to update red bars
                    setState(() {}); 
                  },
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final expense = filtered[i];
                      return Dismissible(
                        key: Key(expense['id'].toString()),
                        // FIXED: Permanently deletes from Supabase
                        onDismissed: (dir) async {
                          final id = expense['id'];
                          await Supabase.instance.client.from('expenses').delete().match({'id': id});
                        },
                        background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.receipt_long, size: 20),
                            ),
                            title: Text(expense['description'] ?? 'No Description'),
                            subtitle: Text("${expense['category']} • ${expense['created_at'].toString().split('T')[0]}"),
                            trailing: Text("₱${expense['amount']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            // NEW: Detail Trigger
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
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile & Settings")),
      body: ListView(
        children: [
          // User Activity Header
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
          
          // DARK MODE TOGGLE
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, currentMode, _) {
              return SwitchListTile(
                title: const Text("Dark Mode"),
                secondary: const Icon(Icons.dark_mode_outlined),
                value: currentMode == ThemeMode.dark,
                onChanged: (bool isDark) async {
                  // 1. Update the UI immediately
                  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

                  // 2. Save the "Memory" to the device
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('is_dark_mode', isDark); // This locks it in for the next restart
                },
              );
            },
          ),

          // ENVELOPE SYSTEM ENTRY POINT
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

          // RECURRING EXPENSES ENTRY POINT
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
                  builder: (c) => BillRegistry(categories: categories)
                ));
              }
            },
          ),
        ],
      ),
    );
  }
}