/// Night by the phone's own clock: 8 PM up to 6 AM, when fewer GoBikers are out.
bool isNightHours(DateTime t) => t.hour >= 20 || t.hour < 6;
