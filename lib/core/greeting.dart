/// "Good Morning!" / "Good Afternoon!" / "Good Evening!" / "Good Night!"
String greetingForNow([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour >= 5 && hour < 12) return 'Good Morning!';
  if (hour >= 12 && hour < 18) return 'Good Afternoon!';
  if (hour >= 18 && hour < 22) return 'Good Evening!';
  return 'Good Night!';
}