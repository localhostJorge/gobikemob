import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/core/live_map.dart';
import 'package:go_bike_app/core/theme.dart';
import 'package:go_bike_app/screens/live_map_screen.dart';

void main() {
  group('map colours', () {
    test(
      'a GoBiker is blue on an ordinary ronda and orange once responding',
      () {
        expect(gobikerColor('active'), AppTheme.blue);
        expect(gobikerColor('responding'), AppTheme.orange);
        // Their own panic alarm keeps its red; it is not one of the two above.
        expect(gobikerColor('emergency'), sosRed);
        // Anything the server adds later is drawn as an ordinary GoBiker.
        expect(gobikerColor('whatever'), AppTheme.blue);
      },
    );

    test('an emergency is red until answered, then yellow, then green', () {
      expect(sosColor('sent'), sosRed);
      expect(sosColor('responding'), sosYellow);
      expect(sosColor('resolved'), sosGreen);
    });

    test('the three colours are all different', () {
      expect({
        gobikerColor('active'),
        gobikerColor('responding'),
        sosColor('resolved'),
      }, hasLength(3));
    });
  });

  group('how far there is left to go', () {
    test('metres under a kilometre, then kilometres to one decimal', () {
      expect(formatDistance(0), '0 m');
      expect(formatDistance(37.4), '37 m');
      expect(formatDistance(999), '999 m');
      expect(formatDistance(1000), '1.0 km');
      expect(formatDistance(2449), '2.4 km');
      expect(formatDistance(12050), '12.1 km');
    });
  });

  test('a resolved SOS is closed, an answered one is still open', () {
    AssignedSos sos(String status) => AssignedSos(
      id: 1,
      status: status,
      residentName: 'Ana Reyes',
      address: '12 Rizal St.',
      landmark: 'Chapel',
    );

    expect(sos('responding').isOpen, isTrue);
    expect(sos('resolved').isOpen, isFalse);
  });
}
