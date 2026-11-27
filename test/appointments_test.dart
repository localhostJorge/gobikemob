import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/core/appointments.dart';
import 'package:go_bike_app/core/auth_service.dart';

void main() {
  test('still reads a GoBiker from an older server that sends a schedule', () {
    final user = AppUser.fromJson({
      'id': 1,
      'name': 'Maria',
      'email': 'm@example.com',
      'role': 'GoBiker',
      'barangay': 'Poblacion',
      'schedule': {
        'days': ['Mon'],
        'start': '08:00',
        'end': '12:00',
      },
    });

    expect(user.isGoBiker, isTrue);
    expect(user.barangay, 'Poblacion');
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

  test('reads the GoBiker the resident chose, from any barangay', () {
    final a = Appointment.fromJson({
      'status': 'pending',
      'gobiker_id': 7,
      'gobiker_name': 'Jose Cruz',
      'gobiker_barangay': 'Hacienda',
    });
    expect(a.gobikerId, 7);
    expect(a.gobikerBarangay, 'Hacienda');

    final g = GobikerOption.fromJson({
      'id': 7,
      'name': 'Jose Cruz',
      'barangay': 'Hacienda',
      'visits_done': 3,
    });
    expect(g.id, 7);
    expect(g.visitsDone, 3);
    expect(GobikerOption.fromJson({'id': 8}).visitsDone, 0);
  });

  test('reads when a GoBiker who declined can be asked again', () {
    final later = DateTime.now().add(const Duration(hours: 5)).toUtc();
    final g = GobikerOption.fromJson({
      'id': 7,
      'ask_again_at': later.toIso8601String(),
    });
    expect(g.askAgainAt!.isAtSameMomentAs(later), isTrue);
    expect(g.waiting, isTrue);

    final none = GobikerOption.fromJson({'id': 8, 'ask_again_at': null});
    expect(none.askAgainAt, isNull);
    expect(none.waiting, isFalse);
  });

  test('says how long until the GoBiker can be asked again', () {
    final now = DateTime(2026, 11, 27, 9);
    expect(
      askAgainLabel(now.add(const Duration(hours: 4, minutes: 1)), now: now),
      'in 5 h',
    );
    expect(
      askAgainLabel(now.add(const Duration(hours: 1)), now: now),
      'in 1 h',
    );
    expect(
      askAgainLabel(now.add(const Duration(minutes: 20)), now: now),
      'in under 1 h',
    );
  });
}
