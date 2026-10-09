import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_tutor_kazakhstan/main.dart';
import 'package:ai_tutor_kazakhstan/tutor_repository.dart';

void main() {
  testWidgets('Unavailable consent does not unlock profile', (tester) async {
    final repository = HttpTutorRepository(
      'http://localhost:8080',
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await tester.pumpWidget(TutorApp(repository: repository));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Серверное сохранение не подтверждено'),
      findsOneWidget,
    );
    expect(find.textContaining('Привет,'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
  testWidgets('Failed attempt never shows success and resize keeps state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <String>[];
    var serverOffline = false;
    final repository = HttpTutorRepository(
      'http://localhost:8080',
      client: MockClient((request) async {
        requests.add(request.url.path);
        if (serverOffline) return http.Response('{}', 503);
        if (request.url.path == '/api/attempt') return http.Response('{}', 503);
        final data = switch (request.url.path) {
          '/api/consent' => {
            'accepted': true,
            'demo': true,
            'session': 'demo-test',
          },
          '/api/profile' => demoProfile,
          '/api/lesson' => demoLesson,
          '/api/progress' => {'completed': 0, 'total': 1},
          '/api/parent' => {
            'profile': demoProfile,
            'progress': {'completed': 0, 'total': 1},
          },
          _ => throw StateError('Unexpected request'),
        };
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
    await tester.tap(find.text('Учиться'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.text('Проверить'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Серверное сохранение не подтверждено'),
      findsOneWidget,
    );
    expect(find.textContaining('Верно!'), findsNothing);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Складываем вместе'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '5',
    );
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Пройдено: 0 / 1'), findsOneWidget);
    await tester.tap(find.text('Родителям'));
    await tester.pumpAndSettle();
    expect(find.text('Уроков завершено: 0 / 1'), findsOneWidget);
    expect(requests.contains('/api/parent'), true);
    tester.view.physicalSize = const Size(1200, 1000);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Уроков завершено: 0 / 1'), findsOneWidget);
    serverOffline = true;
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Пройдено: 0 / 1'), findsOneWidget);
    expect(
      find.textContaining('Серверное сохранение не подтверждено'),
      findsOneWidget,
    );
  });
}
