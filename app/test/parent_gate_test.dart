import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_tutor_kazakhstan/api.dart';
import 'package:ai_tutor_kazakhstan/main.dart';

void main() {
  testWidgets('Adult zone expires after inactivity and PIN field is cleared', (
    tester,
  ) async {
    final api = TutorApi(
      base: Uri.parse('https://example.test/v1/'),
      client: MockClient((r) async {
        final Object response = switch (r.url.path) {
          '/v1/auth/register' => {'token': 'adult', 'family_id': 'family'},
          '/v1/children' => <Object>[],
          '/v1/consents' => {
            'learning': false,
            'voice': false,
            'photo': false,
            'research': false,
          },
          '/v1/billing/trial' => {'status': 'eligible', 'duration_days': 3},
          _ => {},
        };
        return http.Response(jsonEncode(response), 200);
      }),
    );
    await tester.pumpWidget(TutorApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настроить со взрослым'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'test-parent');
    await tester.enterText(fields.at(1), 'adult-test-password');
    await tester.enterText(fields.at(2), '123456');
    await tester.ensureVisible(find.text('Создать семью').last);
    await tester.tap(find.text('Создать семью').last);
    await tester.pumpAndSettle();
    expect(api.pin, '123456');
    await tester.pump(const Duration(minutes: 2, seconds: 1));
    await tester.pumpAndSettle();
    expect(api.pin, isNull);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    api.close();
  });
}
