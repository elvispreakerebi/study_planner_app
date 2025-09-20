import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class MonthlyCalendar extends StatefulWidget {
  const MonthlyCalendar({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
    this.markedDays = const {},
  });

  final DateTime selectedDay;
  final void Function(DateTime selected) onDaySelected;
  final Set<DateTime> markedDays;

  @override
  State<MonthlyCalendar> createState() => _MonthlyCalendarState();
}

class _MonthlyCalendarState extends State<MonthlyCalendar> {
  late DateTime _focusedDay = widget.selectedDay;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return TableCalendar<void>(
      firstDay: DateTime.utc(2015, 1, 1),
      lastDay: DateTime.utc(2100, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const {CalendarFormat.month: 'Month'},
      selectedDayPredicate: (DateTime day) =>
          _isSameDay(day, widget.selectedDay),
      onDaySelected: (DateTime selectedDay, DateTime focusedDay) {
        setState(() => _focusedDay = focusedDay);
        widget.onDaySelected(selectedDay);
      },
      calendarBuilders: CalendarBuilders(
        markerBuilder:
            (BuildContext context, DateTime day, List<dynamic> events) {
              final bool marked = widget.markedDays.any(
                (DateTime d) => _isSameDay(d, day),
              );
              if (!marked) return null;
              return Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
    );
  }
}
