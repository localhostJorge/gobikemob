import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/core/appointments.dart';
import 'package:go_bike_app/core/auth_service.dart';

void main() {
  group('ronda schedule', () {
    test('reads the schedule the admin set and shows it plainly', () {
      final user = AppUser.fromJson({
        'id': 1,
        'name': 'Maria',
        'email': 'm@example.com',
        'role': 'GoBiker',
        'schedule': {
          'days': ['Mon', 'Wed', 'Fri'],
          'start': '08:00',
          'end': '13:30',
        },
      });

      expect(user.schedule?.label, 'Mon, Wed, Fri · 8:00 AM – 1:30 PM');
    });

    test('no schedule when the admin has not set one', () {
      expect(RondaSchedule.fromJson(null), isNull);
      expect(
        RondaSchedule.fromJson({'days': [], 'start': '08:00', 'end': '12:00'}),
        isNull,
      );
    });

    test('midnight and noon read correctly', () {
      const s = RondaSchedule(days: ['Sun'], start: '00:00', end: '12:00');
      expect(s.label, 'Sun · 12:00 AM – 12:00 PM');
    });
  });

  test('reads a visit request', () {
    final a = Appointment.fromJson({
      'id': 9,
      'status': 'accepted',
      'status_label': 'GoBiker assigned',
      'barangay': 'Poblacion',
      'address': 'Purok 3',
      'preferred_date': '2026-10-27',
      'preferred_window': 'afternoon',
      'window_label': 'Afternoon (1 PM – 5 PM)',
      'reason': 'BP check',
      'gobiker_name': 'Maria Santos',
      'decline_note': '',
      'resident_name': 'Ana Reyes',
      'resident_mobile': '09170001111',
      'created_at': '2026-10-24T10:00:00+00:00',
    });

    expect(a.isOpen, isTrue);
    expect(a.preferredDate, DateTime(2026, 10, 27));
    expect(a.gobikerName, 'Maria Santos');
    expect(a.declineNote, isNull);
    expect(a.residentMobile, '09170001111');
    expect(Appointment.fromJson({'status': 'completed'}).isOpen, isFalse);
  });
}
