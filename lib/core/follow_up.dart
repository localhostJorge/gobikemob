/// The admin's decision on whether a person still needs regular check-ups.
///
/// It comes with every patient record from the server (`follow_up`). The same
/// decision applies to every check-up of the same person (same name and
/// contact number), whichever GoBiker recorded it.
class FollowUp {
  const FollowUp({required this.decision, this.note, this.decidedAt});

  /// `stop` or `continue`.
  final String decision;
  final String? note;
  final DateTime? decidedAt;

  bool get isStop => decision == 'stop';

  String get label => isStop ? 'Stop checking' : 'Keep checking';

  /// Identifies this exact decision. It changes when the admin decides again.
  String get signature =>
      '$decision|${decidedAt?.toUtc().toIso8601String() ?? ''}';

  /// Reads the `follow_up` value of a patient map; null when there is no decision.
  static FollowUp? from(dynamic raw) {
    if (raw is FollowUp) return raw;
    if (raw is! Map) return null;
    final decision = raw['decision']?.toString();
    if (decision != 'stop' && decision != 'continue') return null;
    final note = raw['note']?.toString().trim();
    return FollowUp(
      decision: decision!,
      note: (note == null || note.isEmpty) ? null : note,
      decidedAt: DateTime.tryParse('${raw['decided_at'] ?? ''}')?.toLocal(),
    );
  }

  /// Plain map form, so it can sit inside the patient maps the screens share.
  Map<String, dynamic> toMap() => {
    'decision': decision,
    'note': note,
    'decided_at': decidedAt?.toUtc().toIso8601String(),
  };

  /// The decision for the person behind a new check-up, if the app already
  /// knows it from the records it has loaded.
  static FollowUp? forPerson(
    Iterable<Map<String, dynamic>> known, {
    required String name,
    required String contact,
  }) {
    final key = personKey(name, contact);
    if (key == '|') return null;
    for (final patient in known) {
      final patientKey = personKey(
        '${patient['name'] ?? ''}',
        '${patient['contact'] ?? ''}',
      );
      if (patientKey != key) continue;
      final followUp = FollowUp.from(patient['follow_up']);
      if (followUp != null) return followUp;
    }
    return null;
  }

  /// Same rule as the server: name ignoring case and spaces + contact number.
  static String personKey(String name, String contact) =>
      '${name.trim().toLowerCase()}|${contact.trim()}';
}
