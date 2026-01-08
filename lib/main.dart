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
  // Ensure this key name is IDENTICAL in both files
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
  SharedPreferences? _prefs;
  
  final Map<String, Color> _categoryColors = {
    'Food': const Color(0xFFFF5252),
    'Transport': const Color(0xFF448AFF),
    'Shopping': const Color(0xFFFFD740),
    'Bills': const Color(0xFF7C4DFF),
    'Other': const Color(0xFF90A4AE),
  };

  @override
  void initState() {
    super.initState();
    _loadId();
    _initPrefs();
  }

  Future<void> _loadId() async {
    final id = await getOrCreateDeviceId();
    setState(() {
      currentDeviceId = id;
    });
  }

  Future<void> _initPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => _prefs = p);
  }

  Map<String, Color> _getCategoryColorMap() {
    if (_prefs == null) return {};
    final categories = _prefs!.getStringList('user_categories') ?? ['Food', 'Transport', 'Shopping', 'Bills', 'Other'];
    Map<String, Color> colorMap = {};
    for (String cat in categories) {
      final hex = _prefs!.getString('color_$cat');
      if (hex != null) {
        colorMap[cat] = Color(int.parse(hex, radix: 16));
      } else {
        colorMap[cat] = const Color(0xFF6750A4); // Default purple
      }
    }
    return colorMap;
  }

  void _showAddExpenseSheet(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final categories = prefs.getStringList('user_categories') ?? ['Food', 'Transport', 'Shopping', 'Bills', 'Other'];
    
    if (!context.mounted) return;

    final amountController = TextEditingController();
    final descController = TextEditingController();
    String cat = categories.first;
    DateTime selectedDate = DateTime.now();
    Color selectedColor = _categoryColors[cat] ?? const Color(0xFF6750A4);

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
                onChanged: (v) => setSS(() {
                  cat = v!;
                  if (_categoryColors.containsKey(cat)) {
                    selectedColor = _categoryColors[cat]!;
                  }
                }),
              ),
              TextField(controller: descController, decoration: const InputDecoration(labelText: "Description")),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () async {
                Navigator.pop(ctx);
                final deviceId = await getOrCreateDeviceId();
                final prefs = await SharedPreferences.getInstance();

                // FIX 1: Retrieve the color assigned to the category
                String? savedHex = prefs.getString('color_$cat');
                String finalHex = savedHex ?? const Color(0xFF6750A4).value.toRadixString(16).padLeft(8, '0');

                // FIX 2: Date Standardizing (UTC) to stop the 'Next Day' jump
                final now = DateTime.now();
                final finalDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, now.hour, now.minute, now.second);
                
                // FORCE UTC explicitly
                final String utcTimestamp = finalDateTime.toUtc().toIso8601String();

                await Supabase.instance.client.from('expenses').insert({
                  'amount': double.parse(amountController.text),
                  'category': cat,
                  'description': descController.text,
                  'category_color': finalHex, 
                  'device_id': deviceId,
                  'created_at': utcTimestamp, // This 'Z' at the end tells Supabase it is UTC
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
          StatisticsPage(expenses: expenses, categoryColors: _getCategoryColorMap()),
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

class CategoryColorPicker extends StatefulWidget {
  final Function(Color) onColorSelected;
  const CategoryColorPicker({super.key, required this.onColorSelected});

  @override
  State<CategoryColorPicker> createState() => _CategoryColorPickerState();
}

class _CategoryColorPickerState extends State<CategoryColorPicker> {
  Color selected = const Color(0xFFFF5252);
  final List<Color> palette = [
    const Color(0xFFFF5252), const Color(0xFF448AFF), const Color(0xFFFFD740),
    const Color(0xFF00E676), const Color(0xFF7C4DFF), const Color(0xFF00BCD4),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: palette.map((c) => GestureDetector(
        onTap: () {
          setState(() => selected = c);
          widget.onColorSelected(c);
        },
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: c, shape: BoxShape.circle,
            border: Border.all(color: selected == c ? Colors.black : Colors.transparent, width: 2),
          ),
          child: selected == c ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
        ),
      )).toList(),
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
    final savedCategories = prefs.getStringList('user_categories');
    
    // Only update if we actually have saved data to avoid blanking out the UI
    if (savedCategories != null && savedCategories.isNotEmpty) {
      setState(() {
        _userCategories = savedCategories;
        _monthlyBudget = prefs.getDouble('monthly_budget') ?? 10000.0;
        for (String cat in _userCategories) {
          _categoryBudgets[cat] = prefs.getDouble('budget_$cat') ?? 0.0;
        }
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('monthly_budget', _monthlyBudget);
    // Save the updated list to local storage
    await prefs.setStringList('user_categories', _userCategories);
  }

  double _getAmountSpentInCategory(String category) {
    final now = DateTime.now();
    return widget.expenses
        .where((e) {
          final date = DateTime.parse(e['created_at']).toLocal();
          return e['category'] == category && 
                 !_deletedIds.contains(e['id']) &&
                 date.month == now.month &&
                 date.year == now.year;
        })
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

  // 1. The Logic: Executes only AFTER the dialog closes
  void _handleAddNewCategory(String name, Color color) async {
    if (_userCategories.contains(name)) return;

    // Wait 150ms to let the UI finish the "pop" animation to prevent thread lock
    Future.delayed(const Duration(milliseconds: 150), () async {
      setState(() {
        _userCategories.add(name);
        // _categoryColors[name] = color;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('user_categories', _userCategories);
      // Save the color hex so the app remembers it
      await prefs.setString('color_$name', color.value.toRadixString(16));
    });
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    Color pickedColor = const Color(0xFFFF5252); // Default

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("New Category"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: controller, decoration: const InputDecoration(hintText: "Category Name")),
            const SizedBox(height: 20),
            // Using the isolated widget to prevent frame-lock
            CategoryColorPicker(onColorSelected: (c) => pickedColor = c),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                final name = controller.text.trim();
                // THE FIX: Close first, then delay logic to let frames clear
                Navigator.pop(ctx);
                Future.delayed(const Duration(milliseconds: 100), () {
                  _handleAddNewCategory(name, pickedColor);
                });
              }
            }, 
            child: const Text("Add")
          ),
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

  // Helper function to make it more visual
  Widget _getCategoryIcon(String category) {
    IconData icon;
    switch (category.toLowerCase()) {
      case 'food': icon = Icons.restaurant; break;
      case 'transport': icon = Icons.directions_car; break;
      case 'shopping': icon = Icons.shopping_bag; break;
      case 'bills': icon = Icons.receipt; break;
      default: icon = Icons.category;
    }
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: const Color(0xFF6750A4).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 18, color: const Color(0xFF6750A4)),
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
    final now = DateTime.now();

    // FILTER: Only include expenses from the current month and year
    final currentMonthExpenses = widget.expenses.where((e) {
      final date = DateTime.parse(e['created_at']).toLocal();
      return date.month == now.month && 
             date.year == now.year && 
             !_deletedIds.contains(e['id']);
    }).toList();
    
    // Use 'currentMonthExpenses' instead of 'activeExpenses' for calculations
    final totalSpent = currentMonthExpenses.fold<double>(
      0, (sum, item) => sum + (item['amount'] as num).toDouble()
    );

    final budgetPercent = (totalSpent / _monthlyBudget).clamp(0.0, 1.0);
    final budgetColor = budgetPercent > 0.9 ? Colors.red : Colors.green;

    final filtered = _selectedFilter == 'All' 
        ? currentMonthExpenses 
        : currentMonthExpenses.where((e) => e['category'] == _selectedFilter).toList();

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
                  height: 140,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: _userCategories.where((cat) => (_categoryBudgets[cat] ?? 0) > 0).map((cat) {
                      final spent = _getAmountSpentInCategory(cat);
                      final limit = _categoryBudgets[cat]!;
                      final percent = (spent / limit).clamp(0.0, 1.0);
                      final isOver = spent > limit;
                      return Container(
                        width: 170,
                        margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: themeNotifier.value == ThemeMode.dark ? Colors.grey[900] : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Dynamic Icons based on Category Name
                                _getCategoryIcon(cat), 
                                if (isOver) const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                              ],
                            ),
                            const Spacer(),
                            Text(cat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: percent,
                                color: isOver ? Colors.red : const Color(0xFF6750A4),
                                backgroundColor: Colors.grey[200],
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "₱${(limit - spent).toInt()} left", 
                              style: TextStyle(fontSize: 11, color: isOver ? Colors.red : Colors.grey[600], fontWeight: FontWeight.w600)
                            ),
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
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: themeNotifier.value == ThemeMode.dark ? Colors.white.withOpacity(0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.withOpacity(0.1)), // Subtle border
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF6750A4).withOpacity(0.1),
                          child: const Icon(Icons.receipt_long, color: Color(0xFF6750A4), size: 20),
                        ),
                        title: Text(expense['description'] ?? 'No Description', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text("${expense['category']} • ${expense['created_at'].toString().split('T')[0]}", style: const TextStyle(fontSize: 12)),
                        trailing: Text(
                          "₱${expense['amount']}", 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF6750A4))
                        ),
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
        padding: const EdgeInsets.all(16),
        children: [
          // PREMIUM HEADER
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6750A4), Color(0xFF9581CD)]),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, size: 40, color: Colors.white),
                ),
                SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Sintabo User", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    Text("Standard Account", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // SETTINGS SECTION
          _buildSettingsGroup("App Preferences", [
            _settingsTile(Icons.dark_mode_outlined, "Dark Mode", trailing: _darkModeSwitch()),
          ]),
          const SizedBox(height: 16),
          _buildSettingsGroup("Financial Management", [
            _settingsTile(Icons.account_balance_wallet_outlined, "Category Budgets", onTap: () => _navToBudget(context)),
            _settingsTile(Icons.sync, "Recurring Expenses", onTap: () => _navToBills(context)),
          ]),
        ],
      ),
    );
  }

  // Helper for "Island" grouping
  Widget _buildSettingsGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        Container(
          decoration: BoxDecoration(
            color: themeNotifier.value == ThemeMode.dark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _settingsTile(IconData icon, String title, {Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF6750A4)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  Widget _darkModeSwitch() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return Switch(
          value: currentMode == ThemeMode.dark,
          onChanged: (bool isDark) async {
            themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('is_dark_mode', isDark);
          },
        );
      },
    );
  }

  Future<void> _navToBudget(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final categories = prefs.getStringList('user_categories') ?? ['Food', 'Transport', 'Shopping', 'Bills', 'Other'];
    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (c) => CategoryBudgetManager(categories: categories)
      ));
    }
  }

  Future<void> _navToBills(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final categories = prefs.getStringList('user_categories') ?? ['Food', 'Transport', 'Shopping', 'Bills', 'Other'];
    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (c) => BillRegistry(
          categories: categories, 
          expenses: expenses, 
        )
      ));
    }
  }
}

class TotalSpentCard extends StatelessWidget {
  final double amount;
  const TotalSpentCard({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
      decoration: BoxDecoration(
        // Premium Gradient: Deep Purple to a lighter shade
        gradient: const LinearGradient(
          colors: [Color(0xFF6750A4), Color(0xFF9581CD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Total Monthly Spend", 
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)
          ),
          const SizedBox(height: 8),
          Text(
            "₱${amount.toStringAsFixed(2)}",
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }
}