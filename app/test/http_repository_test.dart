import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_tutor_kazakhstan/tutor_repository.dart';

void main() {
  test('HTTP consent profile lesson attempt progress parent flow', () async {
    final paths = <String>[];
    final repository = HttpTutorRepository(
      'http://127.0.0.1:8080',
      client: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path != '/api/consent') {
          expect(request.headers['Authorization'], 'Bearer synthetic-session');
        }
        final result = switch (request.url.path) {
          '/api/consent' => {
            'accepted': true,
            'demo': true,
            'session': 'synthetic-session',
          },
          '/api/profile' => demoProfile,
          '/api/lesson' => demoLesson,
          '/api/progress' => {'completed': 1, 'total': 1},
          '/api/attempt' => {'correct': true, 'completed': true},
          '/api/parent' => {
            'profile': demoProfile,
            'progress': {'completed': 1, 'total': 1},
          },
          _ => throw StateError('Unexpected path'),
        };
        return http.Response(
          jsonEncode(result),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final data = await repository.begin();
    expect(data.profile['names'], demoProfile['names']);
    expect(data.lesson['question'], '3 + 2 = ?');
    expect((await repository.attempt(5)).completed, true);
    expect(await repository.progress(), true);
    expect(await repository.parentProgress(), true);
    expect(paths, [
      '/api/consent',
      '/api/profile',
      '/api/lesson',
      '/api/progress',
      '/api/attempt',
      '/api/progress',
      '/api/parent',
    ]);
    repository.close();
  });
  test('Network errors do not produce success or local fallback', () async {
    final repository = HttpTutorRepository(
      'http://localhost:8080',
      client: MockClient(
        (_) async => throw http.ClientException('unavailable'),
      ),
    );
    await expectLater(repository.begin(), throwsA(isA<http.ClientException>()));
    await expectLater(
      repository.attempt(5),
      throwsA(isA<http.ClientException>()),
    );
    repository.close();
  });
  test('Rejected and malformed server responses fail', () async {
    for (final response in [
      http.Response('{}', 503),
      http.Response('[]', 200),
      http.Response('{}', 200),
    ]) {
      final repository = HttpTutorRepository(
        'http://localhost:8080',
        client: MockClient((_) async => response),
      );
      await expectLater(repository.begin(), throwsA(anything));
      repository.close();
    }
  });
  test('External services cannot be configured in this demo', () {
    expect(
      () => HttpTutorRepository('https://example.com'),
      throwsArgumentError,
    );
    expect(
      () => HttpTutorRepository('http://127.0.0.1:8080/?token=secret'),
      throwsArgumentError,
    );
  });
}
