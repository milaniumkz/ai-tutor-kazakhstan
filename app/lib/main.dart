import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'tutor_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  runApp(const TutorApp());
}

abstract interface class LearningCapabilities {
  bool get aiAvailable;
  bool get voiceAvailable;
  bool get ocrAvailable;
}

class DemoCapabilities implements LearningCapabilities {
  @override
  bool get aiAvailable => false;
  @override
  bool get voiceAvailable => false;
  @override
  bool get ocrAvailable => false;
}

class TutorApp extends StatefulWidget {
  const TutorApp({super.key, this.repository});
  final TutorRepository? repository;
  @override
  State<TutorApp> createState() => _TutorAppState();
}

class _TutorAppState extends State<TutorApp> with WidgetsBindingObserver {
  bool checked = false, consent = false, completed = false, hint = false;
  int page = 0, lang = 0;
  String feedback = '';
  final answer = TextEditingController();
  String t(String ru, String kk, String en) => [ru, kk, en][lang];
  late final TutorRepository repository;
  bool busy = false;
  String? error;
  Map<String, dynamic> profile = demoProfile, lesson = demoLesson;
  String get language => ['ru', 'kk', 'en'][lang];
  String get name => profile['names'][language] as String;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    repository = widget.repository ?? defaultRepository();
  }

  String get unavailable => repository.usesServer
      ? t(
          'Сервер недоступен или вернул ошибку. Серверное сохранение не подтверждено. Повтори действие.',
          'Сервер қолжетімсіз немесе қате қайтарды. Серверге сақтау расталмады. Қайта көр.',
          'Server unavailable or returned an error. Server saving is not confirmed. Please retry.',
        )
      : t(
          'Не удалось прочитать или сохранить прогресс на устройстве. Повтори действие.',
          'Құрылғыдағы прогресті оқу немесе сақтау мүмкін болмады. Қайта көр.',
          'Could not read or save on-device progress. Please retry.',
        );

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      feedback = '';
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => error = unavailable);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> start() => perform(() async {
    final data = await repository.begin();
    if (mounted) {
      setState(() {
        profile = data.profile;
        lesson = data.lesson;
        completed = data.completed;
        consent = true;
      });
    }
  });

  Future<void> go(int target) => perform(() async {
    // Back and lesson navigation remain usable during a server outage.
    if (target != 2 && mounted) setState(() => page = target);
    final value = target == 2
        ? await repository.parentProgress()
        : await repository.progress();
    if (mounted) {
      setState(() {
        completed = value;
        page = target;
      });
    }
  });

  Future<void> submit() async {
    final value = int.tryParse(answer.text.trim());
    if (value == null || value < 0 || value > 20) {
      setState(
        () => feedback = t(
          'Введи число от 0 до 20',
          '0-ден 20-ға дейін сан енгіз',
          'Enter a number from 0 to 20',
        ),
      );
      return;
    }
    await perform(() async {
      final result = await repository.attempt(value);
      if (mounted) {
        setState(() {
          completed = result.completed;
          feedback = result.correct
              ? t(
                  'Верно! Получилось 5 🎉',
                  'Дұрыс! 5 болды 🎉',
                  'Correct! That makes 5 🎉',
                )
              : t(
                  'Попробуй ещё раз. Посчитай яблоки.',
                  'Қайта көр. Алмаларды сана.',
                  'Try again. Count the apples.',
                );
        });
      }
    });
  }

  @override
  void didChangeMetrics() {
    // Explicitly invalidate layout after a browser viewport change.
    // Preserve the lesson, consent and input while the next frame uses new metrics.
    if (mounted) setState(() {});
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    answer.dispose();
    repository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: TutorTokens.primary),
      scaffoldBackgroundColor: TutorTokens.background,
      useMaterial3: true,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(120, TutorTokens.touchTarget),
        ),
      ),
      textTheme: const TextTheme(bodyLarge: TextStyle(fontSize: 20)),
    ),
    home: PopScope(
      canPop: page == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) go(0);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: page > 0
              ? IconButton(
                  onPressed: busy ? null : () => go(0),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: t('Назад', 'Артқа', 'Back'),
                )
              : null,
          title: Text(t('Учимся вместе', 'Бірге үйренеміз', 'Learn together')),
          actions: [
            DropdownButton<int>(
              value: lang,
              items: const [
                DropdownMenuItem(value: 0, child: Text('RU')),
                DropdownMenuItem(value: 1, child: Text('KK')),
                DropdownMenuItem(value: 2, child: Text('EN')),
              ],
              onChanged: (v) => setState(() => lang = v!),
            ),
            const SizedBox(width: 16),
          ],
        ),
        bottomNavigationBar: consent
            ? NavigationBar(
                selectedIndex: page == 2 ? 1 : 0,
                onDestinationSelected: busy ? null : (v) => go(v == 1 ? 2 : 0),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    label: t('Главная', 'Басты бет', 'Home'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.family_restroom),
                    label: t('Родителям', 'Ата-анаға', 'Parents'),
                  ),
                ],
              )
            : null,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TutorTokens.contentWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  t(
                    'ДЕМО • только вымышленные данные',
                    'ДЕМО • тек ойдан шығарылған деректер',
                    'DEMO • synthetic data only',
                  ),
                  style: const TextStyle(color: Color(0xff6456d8)),
                ),
                const SizedBox(height: 8),
                Text(
                  repository.usesServer
                      ? repository.storageMode == 'server-memory-demo'
                            ? t(
                                'Демо API • прогресс в памяти сервера, до перезапуска',
                                'Демо API • прогресс сервер жадында, қайта іске қосқанша',
                                'Demo API • progress in server memory, until restart',
                              )
                            : repository.storageMode == 'postgres-demo'
                            ? t(
                                'Демо API • PostgreSQL, только вымышленные данные',
                                'Демо API • PostgreSQL, тек ойдан шығарылған деректер',
                                'Demo API • PostgreSQL, synthetic data only',
                              )
                            : t(
                                'Демо API • требуется подтверждение сервера',
                                'Демо API • сервердің растауы қажет',
                                'Demo API • server confirmation required',
                              )
                      : t(
                          'Локальное демо • прогресс на устройстве',
                          'Жергілікті демо • прогресс құрылғыда',
                          'Local demo • on-device progress',
                        ),
                ),
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 24),
                if (!consent) ...[
                  Text(
                    t(
                      'Сначала — родитель',
                      'Алдымен — ата-ана',
                      'Parent first',
                    ),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t(
                      'Этот учебный пример использует только вымышленный профиль и не отправляет голос или фотографии. Режим хранения указан выше.',
                      'Бұл оқу мысалы тек ойдан шығарылған профильді қолданады, дауыс пен фото жібермейді. Сақтау режимі жоғарыда көрсетілген.',
                      'This learning demo uses only a synthetic profile and sends no voice or photos. The storage mode is shown above.',
                    ),
                  ),
                  CheckboxListTile(
                    value: checked,
                    onChanged: busy
                        ? null
                        : (v) => setState(() => checked = v!),
                    title: Text(
                      t(
                        'Я родитель и согласен начать демо',
                        'Мен ата-анамын және демоны бастауға келісемін',
                        'I am a parent and agree to start the demo',
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: checked && !busy ? start : null,
                    child: Text(t('Начать', 'Бастау', 'Start')),
                  ),
                ] else if (page == 0) ...[
                  Text(
                    t(
                      'Привет, $name! 👋',
                      'Сәлем, $name! 👋',
                      'Hello, $name! 👋',
                    ),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  Text(
                    t(
                      "Демо-профиль • ${profile['grade']} класс",
                      "Демо-профиль • ${profile['grade']} сынып",
                      "Demo profile • Grade ${profile['grade']}",
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('Математика', 'Математика', 'Mathematics'),
                            style: const TextStyle(fontSize: 28),
                          ),
                          Text(
                            t(
                              'Сложение до 10',
                              '10-ға дейін қосу',
                              'Addition up to 10',
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: busy ? null : () => go(1),
                            child: Text(t('Учиться', 'Үйрену', 'Learn')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "${t('Пройдено:', 'Аяқталды:', 'Completed:')} ${completed ? 1 : 0} / 1",
                  ),
                  Text(
                    t(
                      'Другие предметы появятся позже',
                      'Басқа пәндер кейін қосылады',
                      'More subjects coming later',
                    ),
                  ),
                ] else if (page == 1) ...[
                  Text(
                    t('Складываем вместе', 'Бірге қосамыз', 'Let’s add'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    lesson['visual'] as String,
                    style: TextStyle(fontSize: 30),
                  ),
                  Text(
                    lesson['explanations'][language] as String,
                    style: const TextStyle(fontSize: 22, height: 1.8),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: answer,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: lesson['question'] as String,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(t('Проверить', 'Тексеру', 'Check')),
                  ),
                  Semantics(
                    liveRegion: true,
                    child: Text(feedback, style: const TextStyle(fontSize: 22)),
                  ),
                  TextButton(
                    onPressed: busy ? null : () => setState(() => hint = true),
                    child: Text(t('Подсказка', 'Көмек', 'Hint')),
                  ),
                  if (hint) Text(lesson['hints'][language] as String),
                ] else ...[
                  Text(
                    t(
                      'Обзор для родителя',
                      'Ата-анаға шолу',
                      'Parent overview',
                    ),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    t(
                      '$name • демо-профиль',
                      '$name • демо-профиль',
                      '$name • demo profile',
                    ),
                  ),
                  Text(
                    "${t('Уроков завершено', 'Аяқталған сабақтар', 'Lessons completed')}: ${completed ? 1 : 0} / 1",
                    style: const TextStyle(fontSize: 26),
                  ),
                  Text(lesson['curriculum'] as String),
                  Text(
                    t(
                      'AI, голос и OCR не подключены.',
                      'AI, дауыс және OCR қосылмаған.',
                      'AI, voice and OCR are unavailable.',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
