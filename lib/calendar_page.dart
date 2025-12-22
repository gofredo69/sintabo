import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarPage extends StatefulWidget {
<<<<<<< HEAD
<<<<<<< HEAD
  final List<Map<String, dynamic>> expenses;
  const CalendarPage({super.key, required this.expenses});
=======
  final List<Map<String, dynamic>> expenses; // Pass the data from the main screen
  const CalendarPage({super.key, required this.expenses});

>>>>>>> d7f56cda037f7eb3aa450e6896e81a758cde87f1
=======
  final List<Map<String, dynamic>> expenses; // Pass the data from the main screen
  const CalendarPage({super.key, required this.expenses});

>>>>>>> d7f56cda037f7eb3aa450e6896e81a758cde87f1
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
<<<<<<< HEAD
<<<<<<< HEAD

  @override
  Widget build(BuildContext context) {
    Map<DateTime, double> dailyTotals = {};
    for (var e in widget.expenses) {
      DateTime date = DateTime.parse(e['created_at']).toLocal();
      DateTime dayKey = DateTime(date.year, date.month, date.day);
      dailyTotals[dayKey] = (dailyTotals[dayKey] ?? 0) + (e['amount'] as num).toDouble();
    }

    final dayExpenses = _selectedDay == null 
        ? [] 
        : widget.expenses.where((e) => isSameDay(DateTime.parse(e['created_at']).toLocal(), _selectedDay)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Spending Calendar")),
=======
=======
>>>>>>> d7f56cda037f7eb3aa450e6896e81a758cde87f1
  Map<DateTime, double> _dailyTotals = {};

  @override
  void initState() {
    super.initState();
    _calculateDailyTotals(); // Calculate totals as soon as the page opens
  }

  void _calculateDailyTotals() {
    _dailyTotals = {};
    for (var item in widget.expenses) {
      final date = DateTime.parse(item['created_at']);
      final day = DateTime(date.year, date.month, date.day);
      final amt = (item['amount'] as num).toDouble();
      _dailyTotals[day] = (_dailyTotals[day] ?? 0) + amt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spending Calendar')),
<<<<<<< HEAD
>>>>>>> d7f56cda037f7eb3aa450e6896e81a758cde87f1
=======
>>>>>>> d7f56cda037f7eb3aa450e6896e81a758cde87f1
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
<<<<<<< HEAD
<<<<<<< HEAD
            onDaySelected: (sd, fd) => setState(() { _selectedDay = sd; _focusedDay = fd; }),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final dayKey = DateTime(day.year, day.month, day.day);
                if (dailyTotals.containsKey(dayKey)) {
=======
=======
>>>>>>> d7f56cda037f7eb3aa450e6896e81a758cde87f1
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final dayKey = DateTime(day.year, day.month, day.day);
                if (_dailyTotals.containsKey(dayKey)) {
<<<<<<< HEAD
>>>>>>> d7f56cda037f7eb3aa450e6896e81a758cde87f1
=======
>>>>>>> d7f56cda037f7eb3aa450e6896e81a758cde87f1
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${day.day}'),
<<<<<<< HEAD
<<<<<<< HEAD
                      Text("₱${dailyTotals[dayKey]!.toInt()}", style: const TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold)),
=======
=======
>>>>>>> d7f56cda037f7eb3aa450e6896e81a758cde87f1
                      Text(
                        '₱${_dailyTotals[dayKey]!.toInt()}',
                        style: const TextStyle(
                            fontSize: 9,
                            color: Colors.red,
                            fontWeight: FontWeight.bold),
                      ),
<<<<<<< HEAD
>>>>>>> d7f56cda037f7eb3aa450e6896e81a758cde87f1
=======
>>>>>>> d7f56cda037f7eb3aa450e6896e81a758cde87f1
                    ],
                  );
                }
                return null;
              },
            ),
          ),
<<<<<<< HEAD
<<<<<<< HEAD
          if (_selectedDay != null) ...[
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: dayExpenses.length,
                itemBuilder: (ctx, i) => ListTile(
                  title: Text(dayExpenses[i]['description'] ?? ""),
                  subtitle: Text(dayExpenses[i]['category']),
                  trailing: Text("₱${dayExpenses[i]['amount']}"),
                ),
              ),
            ),
          ]
=======
=======
>>>>>>> d7f56cda037f7eb3aa450e6896e81a758cde87f1
          const Divider(),
          Expanded(
            child: _selectedDay == null
                ? const Center(child: Text("Select a day to see details"))
                : Builder(
                    builder: (context) {
                      // FILTER EXPENSES FOR THE SELECTED DAY
                      final dayExpenses = widget.expenses.where((item) {
                        final date = DateTime.parse(item['created_at']);
                        return isSameDay(date, _selectedDay);
                      }).toList();

                      if (dayExpenses.isEmpty) {
                        return const Center(
                            child: Text("No spending recorded for this day"));
                      }

                      return ListView.builder(
                        itemCount: dayExpenses.length,
                        itemBuilder: (context, index) {
                          final item = dayExpenses[index];
                          return ListTile(
                            leading: const Icon(Icons.shopping_bag_outlined),
                            title: Text(item['description'] ?? 'No Description'),
                            subtitle: Text(item['category']),
                            trailing: Text(
                              '₱${(item['amount'] as num).toDouble().toStringAsFixed(2)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
<<<<<<< HEAD
>>>>>>> d7f56cda037f7eb3aa450e6896e81a758cde87f1
=======
>>>>>>> d7f56cda037f7eb3aa450e6896e81a758cde87f1
        ],
      ),
    );
  }
}