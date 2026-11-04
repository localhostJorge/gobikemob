import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_bike_app/core/age.dart';
import 'package:go_bike_app/core/auth_service.dart';
import 'package:go_bike_app/screens/login_screen.dart';
import 'package:go_bike_app/screens/patient/profile.dart';
import 'package:go_bike_app/widgets/birthday_field.dart';
import 'package:go_bike_app/widgets/photo_crop_screen.dart';
import 'package:go_bike_app/widgets/photo_flow.dart';

/// A 1x1 PNG: a real picture, so the crop screen has something valid to open.
final Uint8List _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0x3F,
  0x00, 0x05, 0xFE, 0x02, 0xFE, 0xDC, 0xCC, 0x59, 0xE7, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  group('age', () {
    test(
      'counts whole years; the day before a birthday is still the year before',
      () {
        final birth = DateTime(2000, 6, 15);
        expect(ageFromBirthdate(birth, DateTime(2026, 6, 15)), 26);
        expect(ageFromBirthdate(birth, DateTime(2026, 6, 14)), 25);
        expect(ageFromBirthdate(birth, DateTime(2026, 6, 16)), 26);
        expect(ageFromBirthdate(birth, DateTime(2026, 1, 1)), 25);
      },
    );

    test('someone born on 29 February has their birthday on 1 March in other years', () {
      final birth = DateTime(2008, 2, 29);
      expect(ageFromBirthdate(birth, DateTime(2026, 2, 28)), 17);
      expect(ageFromBirthdate(birth, DateTime(2026, 3, 1)), 18);
      expect(ageFromBirthdate(birth, DateTime(2028, 2, 29)), 20);
    });

    test('13 is the minimum: today is old enough, tomorrow is not', () {
      expect(kMinimumAge, 13);
      final today = DateTime(2026, 11, 4);
      expect(isOldEnough(DateTime(2013, 11, 4), today), isTrue);
      expect(isOldEnough(DateTime(2013, 11, 5), today), isFalse);
      expect(isOldEnough(DateTime(2014, 11, 4), today), isFalse);
      expect(isOldEnough(DateTime(1990, 1, 1), today), isTrue);
    });

    test('the latest allowed birthdate is exactly 13 years ago, also on a leap day', () {
      expect(latestBirthdate(DateTime(2026, 11, 4)), DateTime(2013, 11, 4));
      // 29 February 2028 minus 13 years has no such date: the 28th is the safe side.
      final leap = latestBirthdate(DateTime(2028, 2, 29));
      expect(leap, DateTime(2015, 2, 28));
      expect(isOldEnough(leap, DateTime(2028, 2, 29)), isTrue);
    });

    test('dates go to the server and come back unchanged', () {
      expect(birthdateToApi(DateTime(2008, 2, 9)), '2008-02-09');
      expect(birthdateFromApi('2008-02-09'), DateTime(2008, 2, 9));
      expect(
        birthdateFromApi('2008-02-09T00:00:00.000000Z'),
        DateTime(2008, 2, 9),
      );
      expect(birthdateFromApi(null), isNull);
      expect(birthdateFromApi(''), isNull);
      expect(birthdateFromApi('soon'), isNull);
      expect(birthdateLabel(DateTime(2008, 3, 5)), 'March 5, 2008');
    });

    test('the signed-in user carries a birthdate and an age', () {
      final user = AppUser.fromJson({
        'id': 1,
        'name': 'Ana Reyes',
        'email': 'ana@example.com',
        'role': 'User',
        'birthdate': '2000-01-01',
      });
      expect(user.birthdate, DateTime(2000, 1, 1));
      expect(user.age, ageFromBirthdate(DateTime(2000, 1, 1), DateTime.now()));

      final older = AppUser.fromJson({'id': 2, 'name': 'B', 'email': 'b@b.c'});
      expect(older.birthdate, isNull);
      expect(older.age, isNull);
    });

    test('says what is wrong with a birthday, or nothing when it is fine', () {
      final today = DateTime(2026, 11, 4);
      expect(
        birthdayError(null, required: true, today: today),
        'Select your birthday',
      );
      expect(birthdayError(null, required: false, today: today), isNull);
      expect(
        birthdayError(DateTime(2014, 1, 1), required: true, today: today),
        'You must be at least 13 years old to register',
      );
      expect(
        birthdayError(DateTime(2013, 11, 4), required: true, today: today),
        isNull,
      );
    });
  });

  group('birthday field', () {
    Future<void> show(
      WidgetTester tester,
      DateTime? value, {
      bool required = true,
    }) {
      final form = GlobalKey<FormState>();
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: form,
              child: Column(
                children: [
                  BirthdayField(
                    value: value,
                    required: required,
                    onChanged: (_) {},
                  ),
                  TextButton(
                    onPressed: () => form.currentState!.validate(),
                    child: const Text('Check'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'shows the age under a date, and explains a date that is too young',
      (tester) async {
        // Born on 1 January, 30 years ago: 30 on any day of the year.
        final adult = DateTime(DateTime.now().year - 30, 1, 1);
        await show(tester, adult);
        expect(find.text('You are 30 years old.'), findsOneWidget);

        final child = DateTime.now().subtract(const Duration(days: 365 * 5));
        await show(tester, child);
        await tester.tap(find.text('Check'));
        await tester.pump();
        expect(
          find.text('You must be at least 13 years old to register'),
          findsOneWidget,
        );
      },
    );

    testWidgets('is required when signing up, optional when editing', (
      tester,
    ) async {
      await show(tester, null);
      await tester.tap(find.text('Check'));
      await tester.pump();
      expect(find.text('Select your birthday'), findsWidgets);
      expect(
        find.text('Select your birthday').evaluate().length,
        greaterThan(1),
      );

      await show(tester, null, required: false);
      await tester.tap(find.text('Check'));
      await tester.pump();
      // Only the hint remains: no error text was added.
      expect(find.text('Select your birthday').evaluate().length, 1);
    });

    testWidgets(
      'opens the date picker, which starts on the youngest age allowed',
      (tester) async {
        DateTime? picked;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BirthdayField(value: null, onChanged: (d) => picked = d),
            ),
          ),
        );

        await tester.tap(find.byType(BirthdayField));
        await tester.pumpAndSettle();
        expect(find.text('Select your birthday'), findsWidgets);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        final today = DateTime.now();
        expect(picked, isNotNull);
        expect(isOldEnough(picked!, today), isTrue);
        expect(ageFromBirthdate(picked!, today), kMinimumAge);
      },
    );
  });

  group('choosing a profile photo', () {
    Future<BuildContext> contextOf(WidgetTester tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      );
      return captured;
    }

    testWidgets('does not ask to crop when nothing was picked', (tester) async {
      final context = await contextOf(tester);
      var cropped = false;

      final path = await pickProfilePhoto(
        context,
        ImageSource.gallery,
        pick: (_) async => null,
        crop: (c, bytes) async {
          cropped = true;
          return bytes;
        },
      );

      expect(path, isNull);
      expect(cropped, isFalse);
    });

    testWidgets('gives nothing back when they cancel at the crop step', (
      tester,
    ) async {
      final context = await contextOf(tester);

      final path = await pickProfilePhoto(
        context,
        ImageSource.camera,
        pick: (_) async => XFile.fromData(_png, path: 'photo.jpg'),
        crop: (c, bytes) async => null,
      );

      expect(path, isNull);
    });

    testWidgets('only the cropped picture is saved, never the original', (
      tester,
    ) async {
      final context = await contextOf(tester);
      final original = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final cropped = Uint8List.fromList([9, 9, 9]);

      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('photo_flow_test');
        Uint8List? shownToCrop;

        final path = await pickProfilePhoto(
          context,
          ImageSource.gallery,
          pick: (_) async => XFile.fromData(original, path: 'holiday.JPG'),
          crop: (c, bytes) async {
            shownToCrop = bytes;
            return cropped;
          },
          tempDir: () async => dir,
        );

        expect(
          shownToCrop,
          original,
          reason: 'the crop screen gets the chosen picture',
        );
        expect(path, isNotNull);
        expect(path, endsWith('.jpg'));
        expect(
          File(path!).readAsBytesSync(),
          cropped,
          reason: 'the saved file is the crop',
        );

        await dir.delete(recursive: true);
      });
    });

    testWidgets('keeps a PNG a PNG', (tester) async {
      final context = await contextOf(tester);

      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('photo_flow_test');
        final path = await pickProfilePhoto(
          context,
          ImageSource.gallery,
          pick: (_) async => XFile.fromData(_png, path: 'logo.PNG'),
          crop: (c, bytes) async => bytes,
          tempDir: () async => dir,
        );
        expect(path, endsWith('.png'));
        await dir.delete(recursive: true);
      });
    });
  });

  // pumpAndSettle would wait forever here: the loading spinner never stops, so each step
  // pumps a fixed time instead.
  group('the crop screen', () {
    Future<void> open(
      WidgetTester tester,
      void Function(Uint8List?) onResult,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  onResult(
                    await Navigator.of(context).push<Uint8List>(
                      MaterialPageRoute(
                        builder: (_) => PhotoCropScreen(image: _png),
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump(); // the route starts its transition
      await tester.pump(const Duration(milliseconds: 700));
    }

    testWidgets('explains itself and offers Cancel and Apply', (tester) async {
      await open(tester, (_) {});

      expect(find.text('Crop photo'), findsOneWidget);
      expect(
        find.text('Drag and pinch to fit your face inside the circle.'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      expect(find.byTooltip('Cancel'), findsOneWidget);

      // Both buttons are comfortable touch targets.
      for (final label in ['Cancel', 'Apply']) {
        final button = find.ancestor(
          of: find.text(label),
          matching: find.bySubtype<ButtonStyleButton>(),
        );
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('Cancel closes it with nothing', (tester) async {
      var closed = false;
      Uint8List? result = Uint8List(1);
      await open(tester, (r) {
        closed = true;
        result = r;
      });

      await tester.tap(find.text('Cancel'));
      await tester.pump(); // the route starts its transition
      await tester.pump(const Duration(milliseconds: 700));

      expect(closed, isTrue);
      expect(result, isNull);
      expect(find.text('Crop photo'), findsNothing);
    });

    testWidgets('the close button cancels too', (tester) async {
      var closed = false;
      await open(tester, (r) => closed = r == null);

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pump(); // the route starts its transition
      await tester.pump(const Duration(milliseconds: 700));

      expect(closed, isTrue);
    });
  });

  group('login', () {
    testWidgets(
      'has no Google button, and keeps the normal login and sign-up',
      (tester) async {
        tester.view.physicalSize = const Size(900, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Continue with Google'), findsNothing);
        expect(find.byType(Image), findsWidgets); // the logo is still there
        expect(find.text('Login'), findsWidgets);
        expect(find.text("Don't have an account?"), findsOneWidget);
      },
    );

    testWidgets(
      'the sign-up link does not overflow on a narrow phone with large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const LoginScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('profile', () {
    testWidgets('shows how old the resident is', (tester) async {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final birth = DateTime(DateTime.now().year - 31, 1, 1);
      final age = ageFromBirthdate(birth, DateTime.now());

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: ProfileTab(
                currentUser: AppUser(
                  id: 1,
                  name: 'Ana Reyes',
                  email: 'ana@example.com',
                  role: 'User',
                  birthdate: birth,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Age $age'), findsOneWidget);
    });
  });
}
