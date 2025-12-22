import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarPage extends StatefulWidget {
  final List<Map<String, dynamic>> expenses; // Pass the data from the main screen
  const CalendarPage({super.key, required this.expenses});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
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
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
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
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${day.day}'),
                      Text(
                        '₱${_dailyTotals[dayKey]!.toInt()}',
                        style: const TextStyle(
                            fontSize: 9,
                            color: Colors.red,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  );
                }
                return null;
              },
            ),
          ),
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
        ],
      ),
    );
  }
}