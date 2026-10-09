import 'package:flutter_test/flutter_test.dart';
import 'package:ai_tutor_kazakhstan/tutor_repository.dart';

void main() {
  const url = String.fromEnvironment('TEST_TUTOR_API_URL');
  test(
    'Real localhost HTTP consent profile lesson attempt progress parent',
    () async {
      final repository = HttpTutorRepository(url);
      addTearDown(repository.close);
      final data = await repository.begin();
      expect(data.profile['synthetic'], true);
      expect(data.lesson['curriculum'], 'demo-synthetic-v1');
      expect(repository.storageMode, 'server-memory-demo');
      final wrong = await repository.attempt(4);
      expect(wrong.correct, false);
      final correct = await repository.attempt(5);
      expect(correct.correct, true);
      expect(correct.completed, true);
      await repository.attempt(5);
      expect(await repository.progress(), true);
      expect(await repository.parentProgress(), true);
    },
    skip: url.isEmpty
        ? 'Set TEST_TUTOR_API_URL to a running localhost demo API'
        : false,
  );
}
