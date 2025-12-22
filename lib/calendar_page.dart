import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarPage extends StatefulWidget {
  final List<Map<String, dynamic>> expenses;
  const CalendarPage({super.key, required this.expenses});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    // 1. Calculate daily totals for grid highlights
    Map<DateTime, double> dailyTotals = {};
    for (var e in widget.expenses) {
      DateTime date = DateTime.parse(e['created_at']).toLocal();
      DateTime dayKey = DateTime(date.year, date.month, date.day);
      dailyTotals[dayKey] = (dailyTotals[dayKey] ?? 0) + (e['amount'] as num).toDouble();
    }

    // 2. Tabulation logic for selected day
    final dayExpenses = _selectedDay == null 
        ? [] 
        : widget.expenses.where((e) {
            DateTime date = DateTime.parse(e['created_at']).toLocal();
            return isSameDay(date, _selectedDay);
          }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Spending Calendar")),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (sd, fd) => setState(() { _selectedDay = sd; _focusedDay = fd; }),
            // RESTORED GRID HIGHLIGHTS
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final dayKey = DateTime(day.year, day.month, day.day);
                if (dailyTotals.containsKey(dayKey)) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${day.day}'),
                      Text("₱${dailyTotals[dayKey]!.toInt()}", 
                        style: const TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  );
                }
                return null;
              },
            ),
          ),
          const Divider(),
          // TABULATION FOR SELECTED DAY
          Expanded(
            child: _selectedDay == null
                ? const Center(child: Text("Select a date to view tabulation"))
                : ListView.builder(
                    itemCount: dayExpenses.length,
                    itemBuilder: (ctx, i) => ListTile(
                      leading: const Icon(Icons.shopping_bag_outlined),
                      title: Text(dayExpenses[i]['description'] ?? "No Description"),
                      subtitle: Text(dayExpenses[i]['category']),
                      trailing: Text("₱${dayExpenses[i]['amount']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}