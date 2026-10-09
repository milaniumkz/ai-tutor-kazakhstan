import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  const TutorApp({super.key});
  @override
  State<TutorApp> createState() => _TutorAppState();
}

class _TutorAppState extends State<TutorApp> {
  bool checked = false, consent = false, completed = false, hint = false;
  int page = 0, lang = 0;
  String feedback = '';
  final answer = TextEditingController();
  String t(String ru, String kk, String en) => [ru, kk, en][lang];
  @override
  void initState() {
    super.initState();
    restoreProgress();
  }

  Future<void> restoreProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(
          () => completed = prefs.getBool('demo.addition.completed') ?? false,
        );
      }
    } catch (_) {
      if (mounted) setState(() => feedback = 'Local storage unavailable');
    }
  }

  Future<void> saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('demo.addition.completed', true);
    } catch (_) {
      if (mounted) {
        setState(
          () => feedback = t(
            'Не удалось сохранить прогресс',
            'Прогресс сақталмады',
            'Could not save progress',
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    answer.dispose();
    super.dispose();
  }

  void go(int target) => setState(() {
    page = target;
    feedback = '';
  });
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
                  onPressed: () => go(0),
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
                onDestinationSelected: (v) => go(v == 1 ? 2 : 0),
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
                      'Этот учебный пример не отправляет голос, фотографии или данные ребёнка внешним AI-сервисам. Прогресс сохраняется на этом устройстве.',
                      'Бұл оқу мысалы дауыс, фото немесе бала деректерін сыртқы AI қызметтеріне жібермейді. Прогресс осы құрылғыда сақталады.',
                      'This learning demo sends no voice, photos or child data to external AI services. Progress is saved on this device.',
                    ),
                  ),
                  CheckboxListTile(
                    value: checked,
                    onChanged: (v) => setState(() => checked = v!),
                    title: Text(
                      t(
                        'Я родитель и согласен начать демо',
                        'Мен ата-анамын және демоны бастауға келісемін',
                        'I am a parent and agree to start the demo',
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: checked
                        ? () => setState(() => consent = true)
                        : null,
                    child: Text(t('Начать', 'Бастау', 'Start')),
                  ),
                ] else if (page == 0) ...[
                  Text(
                    t(
                      'Привет, Алия! 👋',
                      'Сәлем, Әлия! 👋',
                      'Hello, Aliya! 👋',
                    ),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  Text(
                    t(
                      'Демо-профиль • 1 класс',
                      'Демо-профиль • 1 сынып',
                      'Demo profile • Grade 1',
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
                            onPressed: () => go(1),
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
                  const Text(
                    '🍎 🍎 🍎  +  🍎 🍎',
                    style: TextStyle(fontSize: 30),
                  ),
                  Text(
                    t(
                      '1. Было 3 яблока.\n2. Добавили ещё 2.\n3. Посчитай все яблоки.',
                      '1. 3 алма болды.\n2. Тағы 2 алма қостық.\n3. Барлық алманы сана.',
                      '1. Start with 3 apples.\n2. Add 2 more.\n3. Count all the apples.',
                    ),
                    style: const TextStyle(fontSize: 22, height: 1.8),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: answer,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: t('3 + 2 = ?', '3 + 2 = ?', '3 + 2 = ?'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      final n = int.tryParse(answer.text.trim());
                      setState(() {
                        if (n == null || n < 0 || n > 20) {
                          feedback = t(
                            'Введи число от 0 до 20',
                            '0-ден 20-ға дейін сан енгіз',
                            'Enter a number from 0 to 20',
                          );
                        } else if (n == 5) {
                          completed = true;
                          saveProgress();
                          feedback = t(
                            'Верно! Получилось 5 🎉',
                            'Дұрыс! 5 болды 🎉',
                            'Correct! That makes 5 🎉',
                          );
                        } else {
                          feedback = t(
                            'Попробуй ещё раз. Посчитай яблоки.',
                            'Қайта көр. Алмаларды сана.',
                            'Try again. Count the apples.',
                          );
                        }
                      });
                    },
                    child: Text(t('Проверить', 'Тексеру', 'Check')),
                  ),
                  Semantics(
                    liveRegion: true,
                    child: Text(feedback, style: const TextStyle(fontSize: 22)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => hint = true),
                    child: Text(t('Подсказка', 'Көмек', 'Hint')),
                  ),
                  if (hint)
                    Text(
                      t(
                        'Начни с 3, затем скажи 4 и 5.',
                        '3-тен баста, содан кейін 4 және 5 де.',
                        'Start at 3, then say 4 and 5.',
                      ),
                    ),
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
                      'Алия • демо-профиль',
                      'Әлия • демо-профиль',
                      'Aliya • demo profile',
                    ),
                  ),
                  Text(
                    "${t('Уроков завершено', 'Аяқталған сабақтар', 'Lessons completed')}: ${completed ? 1 : 0} / 1",
                    style: const TextStyle(fontSize: 26),
                  ),
                  const Text('demo-synthetic-v1'),
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
