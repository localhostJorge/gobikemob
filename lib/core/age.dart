// Who is old enough to use the app, and how old someone is.
//
// The minimum is the owner's decision (13 and over), not a legal threshold: Philippine law
// sets 18 as the age of majority, and the National Privacy Commission's view is that a minor
// generally cannot give the consent the Data Privacy Act asks for, so a parent or guardian
// should. The server holds the same number in App\Support\Age and is the one that enforces it;
// this copy only lets the form say so before it sends anything.

/// The youngest age that may register.
const int kMinimumAge = 13;

/// Whole years between [birthdate] and [today] (the day before a birthday is still the year
/// before). Only the dates count, not the time of day.
int ageFromBirthdate(DateTime birthdate, DateTime today) {
  var years = today.year - birthdate.year;
  final hadBirthdayThisYear =
      today.month > birthdate.month ||
      (today.month == birthdate.month && today.day >= birthdate.day);
  if (!hadBirthdayThisYear) years--;
  return years;
}

/// Is someone born on [birthdate] at least [kMinimumAge] on [today]?
bool isOldEnough(DateTime birthdate, DateTime today) =>
    ageFromBirthdate(birthdate, today) >= kMinimumAge;

/// The latest birthdate that is old enough today: someone born on it turns 13 today.
DateTime latestBirthdate(DateTime today) {
  // On 29 February "13 years ago" is not a date; the 28th is the safe side of it.
  final day = (today.month == 2 && today.day == 29) ? 28 : today.day;
  return DateTime(today.year - kMinimumAge, today.month, day);
}

/// "2008-02-29", the way the server reads and writes dates.
String birthdateToApi(DateTime birthdate) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${birthdate.year.toString().padLeft(4, '0')}-${two(birthdate.month)}-${two(birthdate.day)}';
}

/// Reads the server's "2008-02-29" (or a full ISO date) back; null when it is empty or odd.
DateTime? birthdateFromApi(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.length < 10) return null;
  final parsed = DateTime.tryParse(text.substring(0, 10));
  return parsed == null
      ? null
      : DateTime(parsed.year, parsed.month, parsed.day);
}

/// "March 5, 2008", for showing in a field.
String birthdateLabel(DateTime birthdate) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[birthdate.month - 1]} ${birthdate.day}, ${birthdate.year}';
}
