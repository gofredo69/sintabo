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
    // 1. Calculate totals
    Map<DateTime, double> dailyTotals = {};
    double focusedMonthTotal = 0.0;

    for (var e in widget.expenses) {
      DateTime date = DateTime.parse(e['created_at']).toLocal();
      
      // Check if expense matches the month currently being viewed (swiped to)
      if (date.month == _focusedDay.month && date.year == _focusedDay.year) {
        focusedMonthTotal += (e['amount'] as num).toDouble();
      }

      DateTime dayKey = DateTime(date.year, date.month, date.day);
      dailyTotals[dayKey] = (dailyTotals[dayKey] ?? 0) + (e['amount'] as num).toDouble();
    }

    // 2. Filter expenses for the specific tapped day
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
          // 3. AUTO-UPDATING MONTHLY TOTAL CARD
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6750A4), Color(0xFF9581CD)]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Monthly Total", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    // Displays the name of the month currently in view
                    Text(
                      "${_getMonthName(_focusedDay.month)} ${_focusedDay.year}", 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                  ],
                ),
                Text("₱${focusedMonthTotal.toStringAsFixed(2)}", 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
              ],
            ),
          ),

          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (sd, fd) => setState(() { _selectedDay = sd; _focusedDay = fd; }),
            
            // THE KEY CHANGE: Update totals when swiping to a new month
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
                _selectedDay = null; // Reset selection so list hides on swipe
              });
            },

            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final dayKey = DateTime(day.year, day.month, day.day);
                if (dailyTotals.containsKey(dayKey)) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${day.day}', style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text("₱${dailyTotals[dayKey]!.toInt()}", 
                          style: const TextStyle(fontSize: 8, color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }
                return null;
              },
            ),
          ),

          // 4. CONDITIONAL TABULATION (Only shows when a day is tapped)
          Expanded(
            child: _selectedDay == null
                ? const Center(child: Text("Tap a date to see daily breakdown", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: dayExpenses.length,
                    itemBuilder: (ctx, i) => _buildDailyTile(dayExpenses[i]),
                  ),
          ),
        ],
      ),
    );
  }

  // Helper for Month Names
  String _getMonthName(int month) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return months[month - 1];
  }

  Widget _buildDailyTile(Map<String, dynamic> expense) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(expense['description'] ?? "No Description"),
        subtitle: Text(expense['category']),
        trailing: Text("₱${expense['amount']}", style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}