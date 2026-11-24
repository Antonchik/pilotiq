/// Moments in time are stored as UTC ISO strings (`...Z`), so that they mean
/// the same instant after a change of time zone or daylight saving time.
/// Calendar dates (the key of a day, the exam date) are not moments and stay
/// local; they do not use these helpers.
String encodeMoment(DateTime d) => d.toUtc().toIso8601String();

/// Reads a stored moment. Records written before 2.0.1 hold the local time
/// without an offset; such a string is read as local time, as it always was.
/// The result is a local [DateTime] of the same instant.
DateTime? decodeMoment(Object? v) {
  if (v is! String) return null;
  return DateTime.tryParse(v)?.toLocal();
}
