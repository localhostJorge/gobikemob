/// Emergency and utility hotlines shown in the resident's Safety tab.
/// Source: Bugallon "Emergency Hotlines" board (October 2026). Update here
/// when a number changes; RHU-1's number is marked temporary.
class Hotline {
  const Hotline({
    required this.name,
    required this.description,
    required this.numbers,
    this.note,
  });

  final String name;
  final String description;

  /// Digits only, ready for a tel: link. The first one is the main number.
  final List<String> numbers;
  final String? note;
}

/// Shown first and largest: works from any phone in the Philippines.
const Hotline kNationalEmergency = Hotline(
  name: '911',
  description: 'National emergency hotline',
  numbers: ['911'],
);

const List<Hotline> kEmergencyHotlines = [
  Hotline(
    name: 'MDRRMO Bugallon',
    description: 'Rescue and disaster response',
    numbers: ['09178427828', '0756330312'],
  ),
  Hotline(
    name: 'PNP Bugallon',
    description: 'Police',
    numbers: ['09985985107'],
  ),
  Hotline(name: 'BFP Bugallon', description: 'Fire', numbers: ['09171856611']),
  Hotline(
    name: 'RHU-1',
    description: 'Rural Health Unit',
    numbers: ['09498255896'],
    note: 'Temporary number',
  ),
];

const List<Hotline> kUtilityHotlines = [
  Hotline(
    name: 'CENPELCO',
    description: 'Electricity: outages, fallen lines',
    numbers: ['09666274040', '09215264101'],
  ),
  Hotline(
    name: 'PAMANA',
    description: 'Water service',
    numbers: ['09455972248', '0756322248'],
  ),
];

/// "09178427828" -> "0917 842 7828", "0756330312" -> "(075) 633 0312".
String formatPhone(String digits) {
  if (digits.length == 11 && digits.startsWith('09')) {
    return '${digits.substring(0, 4)} ${digits.substring(4, 7)} ${digits.substring(7)}';
  }
  if (digits.length == 10 && digits.startsWith('0')) {
    return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)} ${digits.substring(6)}';
  }
  return digits;
}
