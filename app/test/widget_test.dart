import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_tutor_kazakhstan/main.dart';

void main() {
  testWidgets('Welcome fits a mobile browser without overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TutorApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('AI Репетитор'), findsWidgets);
  });
}
