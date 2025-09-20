class DateTimeUtils {
  static DateTime startOfDay(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isOnOrBefore(DateTime a, DateTime b) {
    return a.isBefore(b) || a.isAtSameMomentAs(b);
  }
}
