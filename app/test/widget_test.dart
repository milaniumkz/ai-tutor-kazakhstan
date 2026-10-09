import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_tutor_kazakhstan/main.dart';

void main() {
  testWidgets('Consent starts unchecked and lesson handles retry', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TutorApp());
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      false,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Учиться'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4');
    await tester.tap(find.text('Проверить'));
    await tester.pump();
    expect(find.text('Попробуй ещё раз. Посчитай яблоки.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.text('Проверить'));
    await tester.pump();
    expect(find.text('Верно! Получилось 5 🎉'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Пройдено: 1 / 1'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('demo.addition.completed'), true);
  });
}
