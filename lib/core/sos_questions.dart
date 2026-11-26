/// The two questions a resident answers with an SOS, and the words for each answer.
/// The values are what the server stores; the server sends its own labels back too.
class SosChoice {
  const SosChoice(this.value, this.label, [this.hint = '']);

  final String value;
  final String label;

  /// One line under the label, so "High" means the same to everyone.
  final String hint;
}

/// How serious it is, mildest first.
const List<SosChoice> kSosSeverities = [
  SosChoice('low', 'Low', 'Needs help, but no one is in danger'),
  SosChoice('moderate', 'Moderate', 'Needs help soon'),
  SosChoice('high', 'High', 'Serious, needs help fast'),
  SosChoice('critical', 'Critical', 'Someone could die without help'),
];

/// Whether anyone is hurt.
const List<SosChoice> kSosInjured = [
  SosChoice('yes', 'Yes'),
  SosChoice('no', 'No'),
  SosChoice('unsure', 'Not sure'),
];

/// The label for a stored answer, or null when there is none (an SOS from an older app).
String? sosChoiceLabel(List<SosChoice> choices, String? value) {
  for (final c in choices) {
    if (c.value == value) return c.label;
  }
  return null;
}
