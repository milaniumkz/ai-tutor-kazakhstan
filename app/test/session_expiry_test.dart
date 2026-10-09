import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_tutor_kazakhstan/main.dart';
import 'package:ai_tutor_kazakhstan/tutor_repository.dart';

void main() {
  testWidgets(
    'Restart 403 clears session and requires unchecked consent without reload',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var expired = false;
      var consents = 0;
      var completed = true;
      final fetched = <String>[];
      final repository = HttpTutorRepository(
        'http://localhost:8081',
        client: MockClient((request) async {
          fetched.add(request.url.path);
          if (expired && request.url.path != '/api/consent') {
            return http.Response('{}', 403);
          }
          Map<String, dynamic> data;
          if (request.url.path == '/api/consent') {
            consents++;
            if (consents > 1) {
              expect(request.headers.containsKey('Authorization'), false);
              expired = false;
              completed = false;
            }
            data = {
              'accepted': true,
              'demo': true,
              'session': 'synthetic-$consents',
              'storage': 'server-memory-demo',
            };
          } else {
            expect(
              request.headers['Authorization'],
              'Bearer synthetic-$consents',
            );
            data = switch (request.url.path) {
              '/api/profile' => demoProfile,
              '/api/lesson' => demoLesson,
              '/api/progress' => {'completed': completed ? 1 : 0, 'total': 1},
              _ => throw StateError('Unexpected request'),
            };
          }
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await tester.pumpWidget(TutorApp(repository: repository));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Начать'));
      await tester.pumpAndSettle();
      expect(find.text('Пройдено: 1 / 1'), findsOneWidget);
      await tester.tap(find.text('Учиться'));
      await tester.pumpAndSettle();
      expired = true;
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(repository.session, isNull);
      expect(find.textContaining('Демо-сессия истекла'), findsOneWidget);
      expect(
        find.textContaining('теряется при его перезапуске'),
        findsOneWidget,
      );
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        false,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.text('Пройдено: 1 / 1'), findsNothing);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Начать'));
      await tester.pumpAndSettle();
      expect(consents, 2);
      expect(find.text('Пройдено: 0 / 1'), findsOneWidget);
      expect(fetched.where((path) => path == '/api/profile').length, 2);
      expect(fetched.where((path) => path == '/api/lesson').length, 2);
      expect(find.textContaining('Демо-сессия истекла'), findsNothing);
    },
  );
}
