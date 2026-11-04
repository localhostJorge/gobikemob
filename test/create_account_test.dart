import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/core/age.dart';
import 'package:go_bike_app/screens/create_account_screen.dart';
import 'package:go_bike_app/widgets/birthday_field.dart';

Future<String?> _fakePhoto(BuildContext context, dynamic source) async =>
    'C:/does/not/exist/photo.jpg';

Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.bySubtype<OutlinedButton>(),
);

Future<void> _open(
  WidgetTester tester, {
  PhotoChooser? choosePhoto,
  double width = 900,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: CreateAccountScreen(choosePhoto: choosePhoto),
    ),
  );
  await tester.pumpAndSettle();
}

/// Fills in everything but the photo and the birthday.
Future<void> _fillTheRest(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'Juan Dela Cruz');
  await tester.enterText(find.byType(TextFormField).at(1), 'juan@example.com');
  await tester.enterText(find.byType(TextFormField).at(2), '09171234567');

  await tester.tap(find.text('Select your barangay'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Poblacion').last);
  await tester.pumpAndSettle();

  // Fields in order: name, email, mobile, birthday, then the two passwords.
  await tester.enterText(find.byType(TextFormField).at(4), 'secret-password');
  await tester.enterText(find.byType(TextFormField).at(5), 'secret-password');
  await tester.tap(find.byType(Checkbox));
  await tester.pumpAndSettle();
}

Finder get _createButton =>
    find.widgetWithText(ElevatedButton, 'Create Account');

bool _enabled(WidgetTester tester) =>
    tester.widget<ElevatedButton>(_createButton).onPressed != null;

/// Opens the birthday picker and accepts the date it offers (exactly [kMinimumAge] today).
Future<void> _acceptTheOfferedBirthday(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(BirthdayField));
  await tester.tap(find.byType(BirthdayField));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  group('the photo', () {
    testWidgets('everyone is asked for one, resident and GoBiker alike', (
      tester,
    ) async {
      await _open(tester);

      // Resident is the default, and a photo is asked for from the start.
      expect(find.text('Profile Photo'), findsOneWidget);
      expect(find.text('Required'), findsOneWidget);
      expect(
        find.textContaining('Please upload a clear and formal photo'),
        findsOneWidget,
      );

      await tester.tap(find.text('GoBiker'));
      await tester.pumpAndSettle();
      expect(find.text('Profile Photo'), findsOneWidget);
      expect(find.text('Required'), findsOneWidget);

      await tester.tap(find.text('Resident'));
      await tester.pumpAndSettle();
      expect(find.text('Profile Photo'), findsOneWidget);
    });

    testWidgets('Camera and Gallery sit on one row, Camera on the left', (
      tester,
    ) async {
      for (final (width, scale) in [(900.0, 1.0), (360.0, 1.0), (320.0, 1.3)]) {
        await _open(tester, width: width, textScale: scale);

        final camera = tester.getRect(_button('Camera'));
        final gallery = tester.getRect(_button('Gallery'));

        expect(
          camera.center.dy,
          closeTo(gallery.center.dy, 0.5),
          reason: '$width',
        );
        expect(camera.right, lessThan(gallery.left), reason: '$width');
        // Each is a comfortable touch target.
        expect(camera.height, greaterThanOrEqualTo(48), reason: '$width');
        expect(gallery.height, greaterThanOrEqualTo(48), reason: '$width');
      }
    });

    testWidgets('the Gallery button reads Change once a photo is added', (
      tester,
    ) async {
      await _open(tester, choosePhoto: _fakePhoto);

      await tester.tap(_button('Gallery'));
      await tester.pumpAndSettle();

      expect(find.text('Photo added'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
      expect(find.text('Gallery'), findsNothing);
    });
  });

  group('Create Account', () {
    testWidgets('stays off without a photo, for a resident and a GoBiker', (
      tester,
    ) async {
      await _open(tester);
      await _fillTheRest(tester);
      await _acceptTheOfferedBirthday(tester);

      expect(_enabled(tester), isFalse, reason: 'resident, no photo');

      await tester.tap(find.text('GoBiker'));
      await tester.pumpAndSettle();
      expect(_enabled(tester), isFalse, reason: 'GoBiker, no photo');
    });

    testWidgets('stays off without a birthday', (tester) async {
      await _open(tester, choosePhoto: _fakePhoto);
      await _fillTheRest(tester);
      await tester.tap(_button('Camera'));
      await tester.pumpAndSettle();

      expect(find.text('Photo added'), findsOneWidget);
      expect(_enabled(tester), isFalse, reason: 'no birthday yet');
    });

    testWidgets('turns on once the photo and the birthday are both there', (
      tester,
    ) async {
      await _open(tester, choosePhoto: _fakePhoto);
      await _fillTheRest(tester);
      await tester.tap(_button('Camera'));
      await tester.pumpAndSettle();
      await _acceptTheOfferedBirthday(tester);

      // Exactly the minimum age: the picker opens on it, and "OK" accepts it.
      expect(find.text('You are $kMinimumAge years old.'), findsOneWidget);
      expect(_enabled(tester), isTrue);
    });
  });
}
