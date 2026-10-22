import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:go_bike_app/screens/patient/visit_details_screen.dart';
import 'package:go_bike_app/screens/patient/visit_record.dart';
import 'package:go_bike_app/screens/patient/vital_status.dart';
import 'package:go_bike_app/widgets/patient_form.dart';

Widget _form(PatientFormControllers c, GlobalKey<FormState> key) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: Form(
        key: key,
        child: PatientForm(controllers: c),
      ),
    ),
  ),
);

void main() {
  test('the form sends blood sugar and no height or weight', () {
    final c = PatientFormControllers({
      'name': 'Lola Nena',
      'blood_sugar': '126',
    });
    final map = c.toMap();

    expect(map['blood_sugar'], '126');
    expect(map.containsKey('height'), isFalse);
    expect(map.containsKey('weight'), isFalse);
    c.dispose();
  });

  test('an old record without blood sugar loads as an empty field', () {
    final c = PatientFormControllers({'name': 'Pedro'});

    expect(c.toMap()['blood_sugar'], '');
    c.dispose();
  });

  testWidgets('the form asks for blood sugar, not height and weight', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = PatientFormControllers();
    addTearDown(c.dispose);

    await tester.pumpWidget(_form(c, GlobalKey<FormState>()));

    expect(find.text('Blood sugar (mg/dL) - optional'), findsOneWidget);
    expect(find.text('Height (cm)'), findsNothing);
    expect(find.text('Weight (kg)'), findsNothing);
  });

  testWidgets('blood sugar may be left empty but must be a sensible number', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = PatientFormControllers();
    addTearDown(c.dispose);
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(_form(c, key));

    // Empty: no complaint about blood sugar.
    key.currentState!.validate();
    await tester.pump();
    expect(find.text('Use 20-600'), findsNothing);

    c.bloodSugar.text = '10';
    key.currentState!.validate();
    await tester.pump();
    expect(find.text('Use 20-600'), findsOneWidget);

    c.bloodSugar.text = '95';
    key.currentState!.validate();
    await tester.pump();
    expect(find.text('Use 20-600'), findsNothing);
  });

  group('Vitals.bloodSugar', () {
    test('typical range is 70 to 139 mg/dL', () {
      expect(Vitals.bloodSugar(70, 40)!.label, 'Typical range');
      expect(Vitals.bloodSugar(139, 40)!.label, 'Typical range');
    });

    test('flags high from 140 and low below 70', () {
      expect(Vitals.bloodSugar(140, 40)!.label, 'Above typical range');
      expect(Vitals.bloodSugar(69, 40)!.label, 'Below typical range');
    });

    test('says nothing when the patient was not tested', () {
      expect(Vitals.bloodSugar(null, 40), isNull);
    });
  });

  testWidgets('a visit shows blood sugar, with no height, weight or BMI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: VisitDetailsScreen(record: sampleVisits.first)),
    );

    expect(find.text('Blood sugar'), findsOneWidget);
    expect(find.text('118 mg/dL'), findsOneWidget);
    expect(find.text('Typical range'), findsWidgets);
    expect(find.text('Height'), findsNothing);
    expect(find.text('Weight'), findsNothing);
    expect(find.text('BMI'), findsNothing);
  });

  testWidgets('a visit without a blood sugar says it was not tested', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: VisitDetailsScreen(record: sampleVisits.last)),
    );

    expect(find.text('Not tested'), findsOneWidget);
  });
}
