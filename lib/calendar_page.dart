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
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(color: const Color(0xFF6750A4).withOpacity(0.3), shape: BoxShape.circle),
              selectedDecoration: const BoxDecoration(color: Color(0xFF6750A4), shape: BoxShape.circle),
              markerDecoration: const BoxDecoration(color: Color(0xFF6750A4), shape: BoxShape.circle),
            ),
            // RESTORED GRID HIGHLIGHTS
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final dayKey = DateTime(day.year, day.month, day.day);
                if (dailyTotals.containsKey(dayKey)) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${day.day}', style: const TextStyle(fontWeight: FontWeight.w500)),
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text("₱${dailyTotals[dayKey]!.toInt()}", style: const TextStyle(fontSize: 8, color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 8),
          // TABULATION FOR SELECTED DAY
          Expanded(
            child: _selectedDay == null
                ? const Center(child: Text("Select a date to view tabulation", style: TextStyle(color: Colors.grey)))
                : Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: dayExpenses.length,
                      itemBuilder: (ctx, i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.grey.withOpacity(0.03),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.shopping_bag_outlined, color: Colors.purple, size: 20),
                          ),
                          title: Text(dayExpenses[i]['description'] ?? "No Description", style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(dayExpenses[i]['category'], style: const TextStyle(fontSize: 12)),
                          trailing: Text("₱${dayExpenses[i]['amount']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF6750A4))),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}