/// Calendar-day helpers. All of them work on local calendar dates and never on
/// 24-hour spans, so daylight saving changes cannot shift a day.
library;

DateTime _local(DateTime d) => d.isUtc ? d.toLocal() : d;

/// `yyyy-MM-dd` of the local calendar day of [d].
String dateKey(DateTime d) {
  final l = _local(d);
  final y = l.year.toString().padLeft(4, '0');
  final m = l.month.toString().padLeft(2, '0');
  final day = l.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Parses `yyyy-MM-dd` into a local date (midnight); null if malformed.
DateTime? parseDateKey(String? key) {
  if (key == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final parsed = DateTime(y, mo, d);
  if (parsed.year != y || parsed.month != mo || parsed.day != d) return null;
  return parsed;
}

/// Days since 1970-01-01 of the local calendar day of [d].
int epochDay(DateTime d) {
  final l = _local(d);
  return DateTime.utc(l.year, l.month, l.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}

/// Number of calendar days from [from] to [to] (negative if [to] is earlier).
int calendarDaysBetween(DateTime from, DateTime to) =>
    epochDay(to) - epochDay(from);

/// [d] shifted by [days] calendar days, keeping the wall-clock time.
DateTime addCalendarDays(DateTime d, int days) {
  final l = _local(d);
  return DateTime(
    l.year,
    l.month,
    l.day + days,
    l.hour,
    l.minute,
    l.second,
    l.millisecond,
    l.microsecond,
  );
}
