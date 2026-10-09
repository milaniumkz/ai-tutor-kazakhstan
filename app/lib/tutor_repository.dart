import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DemoSessionExpired implements Exception {
  const DemoSessionExpired();
}

class TutorData {
  const TutorData({
    required this.profile,
    required this.lesson,
    required this.completed,
  });
  final Map<String, dynamic> profile;
  final Map<String, dynamic> lesson;
  final bool completed;
}

class AttemptResult {
  const AttemptResult(this.correct, this.completed);
  final bool correct;
  final bool completed;
}

abstract interface class TutorRepository {
  bool get usesServer;
  String get storageMode;
  Future<TutorData> begin();
  Future<AttemptResult> attempt(int answer);
  Future<bool> progress();
  Future<bool> parentProgress();
  void close();
}

const demoProfile = {
  'id': 'synthetic-aliya',
  'names': {'ru': 'Алия', 'kk': 'Әлия', 'en': 'Aliya'},
  'grade': 1,
  'synthetic': true,
};
const demoLesson = {
  'id': 'addition-1',
  'curriculum': 'demo-synthetic-v1',
  'question': '3 + 2 = ?',
  'visual': '🍎 🍎 🍎  +  🍎 🍎',
  'explanations': {
    'ru': '1. Было 3 яблока.\n2. Добавили ещё 2.\n3. Посчитай все яблоки.',
    'kk': '1. 3 алма болды.\n2. Тағы 2 алма қостық.\n3. Барлық алманы сана.',
    'en': '1. Start with 3 apples.\n2. Add 2 more.\n3. Count all the apples.',
  },
  'hints': {
    'ru': 'Начни с 3, затем скажи 4 и 5.',
    'kk': '3-тен баста, содан кейін 4 және 5 де.',
    'en': 'Start at 3, then say 4 and 5.',
  },
};

class LocalDemoRepository implements TutorRepository {
  @override
  bool get usesServer => false;
  @override
  String get storageMode => 'device-demo';
  @override
  Future<TutorData> begin() async => TutorData(
    profile: demoProfile,
    lesson: demoLesson,
    completed: await progress(),
  );
  @override
  Future<bool> progress() async =>
      (await SharedPreferences.getInstance()).getBool(
        'demo.addition.completed',
      ) ??
      false;
  @override
  Future<bool> parentProgress() => progress();
  @override
  Future<AttemptResult> attempt(int answer) async {
    final correct = answer == 5;
    if (correct) {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool('demo.addition.completed', true)) {
        throw StateError('Local storage unavailable');
      }
    }
    return AttemptResult(correct, await progress());
  }

  @override
  void close() {}
}

/// Localhost-only synthetic API. Never silently falls back to local persistence.
class HttpTutorRepository implements TutorRepository {
  HttpTutorRepository(String baseUrl, {http.Client? client})
    : base = Uri.parse(baseUrl),
      client = client ?? http.Client() {
    if (base.scheme != 'http' ||
        !['localhost', '127.0.0.1'].contains(base.host) ||
        base.userInfo.isNotEmpty ||
        base.query.isNotEmpty ||
        base.fragment.isNotEmpty ||
        !['', '/'].contains(base.path)) {
      throw ArgumentError('Only a localhost demo API is supported');
    }
  }
  final Uri base;
  final http.Client client;
  String? session;
  String mode = 'unconfirmed';
  @override
  String get storageMode => mode;
  @override
  bool get usesServer => true;
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (session != null) 'Authorization': 'Bearer $session',
    };
    final response =
        await (body == null
                ? client.get(base.resolve(path), headers: headers)
                : client.post(
                    base.resolve(path),
                    headers: headers,
                    body: jsonEncode(body),
                  ))
            .timeout(const Duration(seconds: 4));
    if (response.statusCode == 403 &&
        session != null &&
        path != '/api/consent') {
      session = null;
      throw const DemoSessionExpired();
    }
    if (response.statusCode != 200) {
      throw StateError('Demo API request failed (${response.statusCode})');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object');
    }
    if (['server-memory-demo', 'postgres-demo'].contains(data['storage'])) {
      mode = data['storage'] as String;
    }
    return data;
  }

  @override
  Future<TutorData> begin() async {
    final consent = await request('/api/consent', body: {'accepted': true});
    if (consent['accepted'] != true ||
        consent['demo'] != true ||
        consent['session'] is! String) {
      throw const FormatException('Invalid demo consent');
    }
    session = consent['session'] as String;
    final profile = await request('/api/profile');
    final lesson = await request('/api/lesson');
    if (profile['synthetic'] != true ||
        profile['names'] is! Map ||
        profile['grade'] is! int ||
        lesson['question'] is! String ||
        lesson['visual'] is! String ||
        lesson['explanations'] is! Map ||
        lesson['hints'] is! Map ||
        lesson['curriculum'] != 'demo-synthetic-v1') {
      throw const FormatException('Invalid synthetic learning content');
    }
    for (final language in ['ru', 'kk', 'en']) {
      if (profile['names'][language] is! String ||
          lesson['explanations'][language] is! String ||
          lesson['hints'][language] is! String) {
        throw const FormatException('Missing translation');
      }
    }
    return TutorData(
      profile: profile,
      lesson: lesson,
      completed: await progress(),
    );
  }

  @override
  Future<AttemptResult> attempt(int answer) async {
    final data = await request('/api/attempt', body: {'answer': answer});
    if (data['correct'] is! bool || data['completed'] is! bool) {
      throw const FormatException('Invalid attempt');
    }
    return AttemptResult(data['correct'] as bool, data['completed'] as bool);
  }

  bool parseProgress(Map<String, dynamic> data) {
    if (![0, 1].contains(data['completed']) || data['total'] != 1) {
      throw const FormatException('Invalid progress');
    }
    return data['completed'] == 1;
  }

  @override
  Future<bool> progress() async =>
      parseProgress(await request('/api/progress'));
  @override
  Future<bool> parentProgress() async {
    final data = await request('/api/parent');
    if (data['profile'] is! Map ||
        data['profile']['synthetic'] != true ||
        data['progress'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid parent overview');
    }
    return parseProgress(data['progress'] as Map<String, dynamic>);
  }

  @override
  void close() => client.close();
}

TutorRepository defaultRepository() {
  const url = String.fromEnvironment('TUTOR_API_URL');
  return url.isEmpty ? LocalDemoRepository() : HttpTutorRepository(url);
}
