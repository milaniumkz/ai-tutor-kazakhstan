import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'api.dart';
import 'l10n/generated/app_localizations.dart';

const ink = Color(0xFF203047),
    teal = Color(0xFF167D8D),
    purple = Color(0xFF7C6BC4),
    warm = Color(0xFFF4C95D),
    background = Color(0xFFF7F9FC),
    mint = Color(0xFFE4F3F1);
void main() => runApp(const TutorApp());

class TutorApp extends StatefulWidget {
  const TutorApp({super.key, this.api});
  final TutorApi? api;
  @override
  State<TutorApp> createState() => _TutorAppState();
}

class _TutorAppState extends State<TutorApp> {
  Locale locale = const Locale('ru', 'KZ');
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AI Репетитор',
    debugShowCheckedModeBanner: false,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      fontFamily: 'NotoSans',
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        primary: teal,
        secondary: purple,
        surface: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 19, color: ink),
        bodyMedium: TextStyle(fontSize: 17, color: ink),
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        headlineSmall: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.all(18),
      ),
    ),
    home: TutorShell(
      api: widget.api,
      onLocale: (value) => setState(() => locale = value),
    ),
  );
}

class TutorShell extends StatefulWidget {
  const TutorShell({super.key, this.api, required this.onLocale});
  final TutorApi? api;
  final ValueChanged<Locale> onLocale;
  @override
  State<TutorShell> createState() => _TutorShellState();
}

class _TutorShellState extends State<TutorShell> {
  late final TutorApi api = widget.api ?? TutorApi();
  Timer? parentIdleTimer;
  late final AppLifecycleListener lifecycle;
  @override
  void initState() {
    super.initState();
    lifecycle = AppLifecycleListener(onHide: lockParent, onPause: lockParent);
  }

  void touchParent() {
    parentIdleTimer?.cancel();
    if (api.pin != null) {
      parentIdleTimer = Timer(const Duration(minutes: 2), lockParent);
    }
  }

  void lockParent() {
    if (!mounted) return;
    api.pin = null;
    field('pin').clear();
    field('privacy_password').clear();
    privacyJobs = [];
    exportText = '';
    progress = [];
    if (screen.startsWith('P') && screen != 'P01' && deletionReceipt == null) {
      go('G01');
    }
  }

  final controllers = <String, TextEditingController>{};
  String screen = 'C01', authMode = 'register', error = '', feedback = '';
  bool busy = false;
  List<dynamic> privacyJobs = [];
  Map<String, dynamic>? deletionReceipt;
  String privacyKind = 'export', privacyScope = '', exportText = '';
  List<dynamic> children = [], lessons = [], progress = [];
  Map<String, dynamic>? child, session, trial, quote;
  Map<String, dynamic> consents = {};
  final selected = <String>{};
  int grade = 1;
  String language = 'ru-KZ';
  final consentSelection = {
    'learning': false,
    'voice': false,
    'photo': false,
    'research': false,
  };
  AppLocalizations get l => AppLocalizations.of(context)!;
  TextEditingController field(String key) =>
      controllers.putIfAbsent(key, () => TextEditingController());
  @override
  void dispose() {
    parentIdleTimer?.cancel();
    lifecycle.dispose();
    for (final c in controllers.values) {
      c.dispose();
    }
    if (widget.api == null) api.close();
    super.dispose();
  }

  void go(String value) {
    setState(() {
      if (value.startsWith('C')) {
        api.pin = null;
        parentIdleTimer?.cancel();
        privacyJobs = [];
        exportText = '';
      }
      screen =
          value.startsWith('P') &&
              value != 'P01' &&
              api.pin == null &&
              deletionReceipt == null
          ? 'G01'
          : value;
      error = '';
      feedback = '';
    });
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiError ? message(e.code) : l.offline);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String message(String code) => switch (code) {
    'CURRICULUM_UNAVAILABLE' => l.unavailable,
    'ACCESS_REQUIRED' => l.trialExpired,
    'AUTH_REQUIRED' || 'PARENT_AUTH_REQUIRED' => l.login,
    'CONTENT_ROLE_REQUIRED' || 'ADMIN_AUTH_REQUIRED' => l.parents,
    _ => l.repeat,
  };
  Future<void> family() async {
    children = await api.request('children', parent: true);
    consents = await api.request('consents', parent: true);
    trial = await api.request('billing/trial', parent: true);
    for (final key in consentSelection.keys) {
      consentSelection[key] = consents[key] == true;
    }
  }

  Future<void> adult() async {
    api.pin = null;
    field('pin').clear();
    exportText = '';
    privacyJobs = [];
    go(api.adultToken == null ? 'P01' : 'G01');
  }

  Widget primary(String text, VoidCallback action) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: FilledButton(
      onPressed: busy ? null : action,
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
  Widget secondary(String text, VoidCallback action) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      onPressed: busy ? null : action,
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
  Widget title(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Text(text, style: Theme.of(context).textTheme.headlineLarge),
  );
  Widget textField(
    String name,
    String label, {
    bool secret = false,
    TextInputType? type,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextField(
      controller: field(name),
      onChanged: (_) => touchParent(),
      obscureText: secret,
      keyboardType: type,
      autocorrect: !secret,
      enableSuggestions: !secret,
      decoration: InputDecoration(labelText: label),
    ),
  );
  Widget panel(Widget content, {Color color = Colors.white}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    margin: const EdgeInsets.only(bottom: 18),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xFFDDE7EF)),
    ),
    child: content,
  );
  Widget note(String text) => panel(
    Text(text, style: const TextStyle(fontSize: 15, color: Color(0xFF62748E))),
  );
  Widget routeCard(
    IconData icon,
    String label,
    String subtitle,
    VoidCallback action,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFDDE7EF)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: busy ? null : action,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: mint,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, size: 34, color: ink),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF62748E),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final parent =
        screen.startsWith('P') ||
        screen.startsWith('G') ||
        screen.startsWith('A');
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (busy) const LinearProgressIndicator(),
        if (error.isNotEmpty) Semantics(liveRegion: true, child: note(error)),
        ...content(),
      ],
    );
    return Listener(
      onPointerDown: (_) => touchParent(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(
            l.appTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          actions: [
            PopupMenuButton<Locale>(
              tooltip: l.instructionLanguage,
              onSelected: widget.onLocale,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: Locale('ru', 'KZ'),
                  child: Text('Русский'),
                ),
                PopupMenuItem(
                  value: Locale('kk', 'KZ'),
                  child: Text('Қазақша'),
                ),
                PopupMenuItem(value: Locale('en'), child: Text('English')),
              ],
            ),
            IconButton(
              tooltip: l.parents,
              onPressed: busy ? null : adult,
              icon: const Icon(Icons.lock_outline),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 1120 : 460),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wide)
                    SizedBox(
                      width: 220,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            routeCard(
                              Icons.home_outlined,
                              l.home,
                              '',
                              () => go(child == null ? 'C01' : 'C03'),
                            ),
                            routeCard(
                              Icons.menu_book_outlined,
                              l.study,
                              '',
                              catalog,
                            ),
                            routeCard(
                              Icons.person_outline,
                              l.parents,
                              '',
                              adult,
                            ),
                            if (api.pin != null)
                              secondary(l.subscription, () => go('P07')),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(wide ? 30 : 22),
                      child: body,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: wide || parent
            ? null
            : NavigationBar(
                height: 82,
                selectedIndex: screen == 'C04' || screen == 'C05'
                    ? 1
                    : screen == 'C07'
                    ? 2
                    : 0,
                onDestinationSelected: (index) {
                  if (index == 0) go(child == null ? 'C01' : 'C03');
                  if (index == 1) catalog();
                  if (index == 2) go('C07');
                },
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    label: l.home,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.menu_book_outlined),
                    label: l.study,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.mic_none),
                    label: l.ask,
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> content() {
    switch (screen) {
      case 'C01':
        return [
          const Center(child: Owl(size: 130)),
          title(l.welcome),
          Text(l.introduction),
          primary(l.setupAdult, adult),
          note(l.voiceUnavailable),
        ];
      case 'P01':
        return [
          title(l.family),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'register', label: Text(l.register)),
              ButtonSegment(value: 'login', label: Text(l.login)),
            ],
            selected: {authMode},
            onSelectionChanged: (v) => setState(() => authMode = v.first),
          ),
          const SizedBox(height: 24),
          textField('login', l.username),
          textField('password', l.password, secret: true),
          if (authMode == 'register')
            textField('pin', l.pin, secret: true, type: TextInputType.number),
          primary(
            authMode == 'register' ? l.register : l.login,
            () => run(() async {
              final data = {
                'login': field('login').text,
                'password': field('password').text,
                if (authMode == 'register') 'pin': field('pin').text,
              };
              final result = await api.request('auth/$authMode', data: data);
              api.clear();
              api.adultToken = result['token'];

              child = null;
              session = null;
              children = [];
              selected.clear();
              if (authMode == 'register') {
                api.pin = field('pin').text;
                touchParent();
                touchParent();
                await family();
                go('P02');
              } else {
                go('G01');
              }
              field('password').clear();
              field('pin').clear();
            }),
          ),
        ];
      case 'G01':
        return [
          title(l.parents),
          textField('pin', l.pin, secret: true, type: TextInputType.number),
          primary(
            l.continueLesson,
            () => run(() async {
              api.pin = field('pin').text;
              touchParent();
              await family();
              field('pin').clear();
              go('P04');
            }),
          ),
          secondary(l.login, () => go('P01')),
        ];
      case 'P02':
        return [
          title(l.consents),
          ...[
            ("learning", l.learningConsent),
            ("voice", l.voiceConsent),
            ("photo", l.photoConsent),
            ("research", l.researchConsent),
          ].map(
            (item) => CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              title: Text(item.$2),
              value: consentSelection[item.$1],
              onChanged: busy
                  ? null
                  : (v) =>
                        setState(() => consentSelection[item.$1] = v ?? false),
            ),
          ),
          primary(
            l.save,
            () => run(() async {
              for (final key in consentSelection.keys) {
                if (consents[key] != consentSelection[key]) {
                  consents = await api.request(
                    'consents',
                    parent: true,
                    data: {
                      'purpose': key,
                      'version': 'engineering-v1',
                      'granted': consentSelection[key],
                    },
                  );
                }
              }
              go('P04');
            }),
          ),
        ];
      case 'P04':
        return [
          title(l.family),
          trialPanel(),
          ...children.map(
            (c) => routeCard(
              Icons.face,
              c['nickname'],
              '${c['grade']} · ${c['instruction_language']}',
              () => chooseChild(c),
            ),
          ),
          primary(l.addChild, () => go('P03')),
          secondary(l.subscription, () => go('P07')),
          secondary(
            l.progress,
            () => run(() async {
              progress = [];
              for (final c in children) {
                progress.add(
                  await api.request(
                    'progress?child_id=${c['id']}',
                    parent: true,
                  ),
                );
              }
              go('P05');
            }),
          ),
          secondary(l.consents, () => go('P02')),
          secondary(l.privacy, openPrivacy),
          secondary(l.exit, logout),
        ];
      case 'P03':
        return [
          title(l.addChild),
          textField('nickname', l.nickname),
          DropdownButtonFormField<int>(
            initialValue: grade,
            decoration: InputDecoration(labelText: l.grade),
            items: [1, 2, 3, 4]
                .map((g) => DropdownMenuItem(value: g, child: Text('$g')))
                .toList(),
            onChanged: (v) => setState(() => grade = v ?? 1),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: language,
            decoration: InputDecoration(labelText: l.instructionLanguage),
            items: const [
              DropdownMenuItem(value: 'ru-KZ', child: Text('Русский')),
              DropdownMenuItem(value: 'kk-KZ', child: Text('Қазақша')),
            ],
            onChanged: (v) => setState(() => language = v ?? 'ru-KZ'),
          ),
          primary(
            l.save,
            () => run(() async {
              await api.request(
                'children',
                parent: true,
                data: {
                  'nickname': field('nickname').text,
                  'grade': grade,
                  'age_band': grade <= 2 ? '6-7' : '8-9',
                  'instruction_language': language,
                  'avatar': 'owl',
                },
              );
              field('nickname').clear();
              await family();
              go('P04');
            }),
          ),
        ];
      case 'C02':
        return [
          title(l.family),
          ...children.map(
            (c) => routeCard(
              Icons.face,
              c['nickname'],
              '${c['grade']}',
              () => chooseChild(c),
            ),
          ),
        ];
      case 'C03':
        return [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child?['nickname'] ?? '',
                      style: const TextStyle(
                        letterSpacing: 2,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF62748E),
                      ),
                    ),
                    const SizedBox(height: 12),
                    title(l.headline),
                  ],
                ),
              ),
              const Owl(size: 88),
            ],
          ),
          if (lessons.isNotEmpty)
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(label: Text('${l.grade} ${child?['grade'] ?? 1}')),
                  Text(
                    lessons.first['title'],
                    style: const TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF184D59),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l.introduction),
                  primary(l.continueLesson, () => start(lessons.first['id'])),
                ],
              ),
              color: mint,
            )
          else
            note(l.unavailable),
          routeCard(Icons.menu_book_outlined, l.subjects, l.study, catalog),
          routeCard(Icons.mic_none, l.ask, l.introduction, () => go('C07')),
          routeCard(
            Icons.photo_camera_outlined,
            l.photo,
            l.study,
            () => go('C11'),
          ),
        ];
      case 'C04':
        return [
          title(l.subjects),
          routeCard(
            Icons.calculate_outlined,
            'Математика',
            l.study,
            () => go('C05'),
          ),
          routeCard(
            Icons.menu_book_outlined,
            'Грамотность',
            l.unavailable,
            () => setState(() => error = l.unavailable),
          ),
          routeCard(
            Icons.nature_people_outlined,
            'Познание мира',
            l.unavailable,
            () => setState(() => error = l.unavailable),
          ),
        ];
      case 'C05':
        return [
          title(l.study),
          if (lessons.isEmpty) note(l.unavailable),
          ...lessons.map(
            (x) => routeCard(
              Icons.auto_stories_outlined,
              x['title'],
              x['source'] ?? '',
              () => start(x['id']),
            ),
          ),
        ];
      case 'C06':
      case 'C15':
      case 'C16':
        return lessonView();
      case 'C17':
        return [
          title(l.result),
          panel(
            Column(
              children: [
                const Icon(Icons.eco_outlined, size: 90, color: teal),
                const SizedBox(height: 22),
                Text(l.savedResult),
                primary(l.home, () => go('C03')),
              ],
            ),
            color: mint,
          ),
        ];
      case 'C19':
        return [
          title(l.paused),
          const Center(
            child: Icon(Icons.cloud_outlined, size: 100, color: purple),
          ),
          primary(l.continueLesson, () => transition('resume')),
          secondary(l.exit, () => transition('cancel')),
        ];
      case 'C07':
      case 'C08':
      case 'C09':
      case 'C10':
      case 'G03':
        return [
          title(l.ask),
          const Center(child: Owl(size: 130)),
          note(l.voiceUnavailable),
          primary(l.study, catalog),
        ];
      case 'C11':
      case 'C12':
      case 'C13':
      case 'C14':
        return [
          title(l.photo),
          const Center(
            child: Icon(Icons.photo_camera_outlined, size: 100, color: teal),
          ),
          note(l.photoUnavailable),
          primary(l.study, catalog),
        ];
      case 'C18':
        return [
          title(l.offline),
          primary(l.repeat, catalog),
          secondary(l.home, () => go('C03')),
        ];
      case 'P05':
        return [
          title(l.progress),
          ...progress.map(
            (p) => panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    children.firstWhere(
                      (c) => c['id'] == p['child_id'],
                    )['nickname'],
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    '${p['completed_sessions']}',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  Text(l.savedResult),
                  ...(p['topics'] ?? []).map<Widget>(
                    (t) => panel(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t['title']),
                          Text(
                            '${l.independentTransfer}: ${t['independent_transfer']}',
                          ),
                          Text(
                            '${l.assistedTransfer}: ${t['assisted_transfer']}',
                          ),
                          Text('${l.hintsCount}: ${t['hints']}'),
                          Text(t['curriculum_version']),
                          Text(l.evidenceNotice),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
      case 'P07':
        return [
          title(l.subscription),
          trialPanel(),
          ...children.map(
            (c) => CheckboxListTile(
              title: Text(c['nickname']),
              subtitle: Text('${l.grade} ${c['grade']}'),
              value: selected.contains(c['id']),
              onChanged: (v) => setState(() {
                v == true ? selected.add(c['id']) : selected.remove(c['id']);
                quote = null;
              }),
            ),
          ),
          primary(
            l.quote,
            () => run(() async {
              quote = await api.request(
                'billing/quote',
                parent: true,
                data: {'child_ids': selected.toList()},
              );
            }),
          ),
          if (quote != null)
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${quote!['total_amount']} ₸ / месяц',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  ...quote!['items'].map<Widget>(
                    (i) => Text('${i['nickname']} · ${i['unit_amount']} ₸'),
                  ),
                  note('Оплата ещё не подключена.'),
                ],
              ),
            ),
          secondary(l.back, () => go('P04')),
        ];
      case 'P08':
        return privacyView();
      default:
        return [title(l.unavailable), secondary(l.back, () => go('C03'))];
    }
  }

  Widget trialPanel() {
    final t = trial;
    if (t == null) return const SizedBox.shrink();
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t['status'] == 'eligible'
                ? l.trialTitle(t['duration_days'])
                : t['status'] == 'active'
                ? l.trialActive
                : l.trialExpired,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 14),
          Text(l.trialDetails),
          if (t['status'] == 'eligible')
            primary(
              l.startTrial,
              () => run(() async {
                trial = await api.request(
                  'billing/trial',
                  parent: true,
                  data: {},
                  key: const Uuid().v4(),
                );
              }),
            ),
        ],
      ),
      color: mint,
    );
  }

  Future<void> chooseChild(dynamic c) => run(() async {
    child = Map<String, dynamic>.from(c);
    final r = await api.request(
      'children/${c['id']}/access',
      parent: true,
      data: {},
    );
    api.childToken = r['token'];
    api.pin = null;
    privacyJobs = [];
    exportText = '';
    field('privacy_password').clear();
    session = null;
    lessons = (await api.request('curriculum'))['lessons'];
    go('C03');
  });
  Future<void> catalog() => run(() async {
    if (api.childToken == null) {
      go('C01');
      return;
    }
    lessons = (await api.request('curriculum'))['lessons'];
    go('C04');
  });
  Future<void> start(String id) => run(() async {
    session = await api.request(
      'sessions',
      data: {'lesson_id': id},
      key: const Uuid().v4(),
    );
    go('C06');
  });
  Future<void> answer(int value) => run(() async {
    final s = session!, key = const Uuid().v4();
    final r = await api.request(
      'sessions/${s['id']}/attempts',
      revision: s['revision'],
      key: key,
      data: {
        'client_event_id': key,
        'task_revision': s['task_revision'],
        'step_id': s['step_id'],
        'input': {'type': 'choice', 'value': value},
      },
    );
    session = Map<String, dynamic>.from(r['session']);
    feedback = r['feedback'];
    screen = session!['state'] == 'completed' ? 'C17' : 'C15';
  });
  Future<void> transition(String action) => run(() async {
    session = await api.request(
      'sessions/${session!['id']}/$action',
      data: {},
      revision: session!['revision'],
    );
    go(
      action == 'pause'
          ? 'C19'
          : action == 'resume'
          ? 'C06'
          : 'C03',
    );
  });
  List<Widget> lessonView() {
    final s = session;
    if (s == null) return [note(l.unavailable)];
    final board = s['board'];
    final choices = (s['choices'] ?? [6, 7, 8]) as List;
    final boardWidget = panel(
      Semantics(
        label: board['alt_text'],
        child: Column(
          children: [
            if (board['groups'] != null)
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (int g = 0; g < board['groups'].length; g++)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (int n = 0; n < board['groups'][g]; n++)
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: g == 0 ? teal : purple,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            const SizedBox(height: 28),
            Text(
              s['question'],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
    final controls = Column(
      children: [
        Row(
          children: choices
              .map<Widget>(
                (n) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(56, 76),
                        textStyle: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: busy ? null : () => answer(n),
                      child: Text('$n'),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        if (feedback.isNotEmpty)
          Semantics(liveRegion: true, child: note(feedback)),
        secondary(
          l.help,
          () => run(() async {
            final result = await api.request(
              'sessions/${s['id']}/hints',
              data: {},
              key: const Uuid().v4(),
              revision: s['revision'],
            );
            session = Map<String, dynamic>.from(result['session']);
            feedback = result['hint'];
          }),
        ),
        secondary(l.pause, () => transition('pause')),
        secondary(l.exit, () => transition('cancel')),
      ],
    );
    return [
      title(s['title'] ?? l.study),
      LinearProgressIndicator(value: s['step'] == 0 ? 0.5 : 1.0),
      const SizedBox(height: 24),
      if (s['explanation'] != null) note(s['explanation']),
      LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 650
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: boardWidget),
                  const SizedBox(width: 24),
                  Expanded(child: controls),
                ],
              )
            : Column(children: [boardWidget, controls]),
      ),
    ];
  }

  Future<void> openPrivacy() => run(() async {
    privacyJobs = await api.request('privacy/jobs', parent: true);
    exportText = '';
    go('P08');
  });
  String jobLabel(String status) => switch (status) {
    'queued' => l.queued,
    'completed' => l.completed,
    'cancelled' => l.cancelled,
    _ => l.repeat,
  };
  Future<void> refreshPrivacy() => run(() async {
    if (deletionReceipt != null) {
      final r = await api.request(
        'privacy/receipts/${deletionReceipt!['id']}',
        bearerOverride: deletionReceipt!['receipt_token'],
      );
      deletionReceipt = {...deletionReceipt!, ...Map<String, dynamic>.from(r)};
    } else {
      privacyJobs = await api.request('privacy/jobs', parent: true);
      await family();
    }
  });
  List<Widget> privacyView() {
    if (deletionReceipt != null) {
      return [
        title(l.deleteData),
        note(l.deletionAccepted),
        note(jobLabel(deletionReceipt!['state'])),
        note(l.privacyWarning),
        secondary(l.refreshJobs, refreshPrivacy),
      ];
    }
    return [
      title(l.privacy),
      note(l.exportNotice),
      DropdownButtonFormField<String>(
        initialValue: privacyKind,
        items: [
          DropdownMenuItem(value: 'export', child: Text(l.exportData)),
          DropdownMenuItem(value: 'deletion', child: Text(l.deleteData)),
        ],
        onChanged: (v) => setState(() => privacyKind = v!),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: privacyScope,
        items: [
          DropdownMenuItem(value: '', child: Text(l.allFamily)),
          ...children.map<DropdownMenuItem<String>>(
            (c) => DropdownMenuItem(value: c['id'], child: Text(c['nickname'])),
          ),
        ],
        onChanged: (v) => setState(() => privacyScope = v!),
      ),
      textField('privacy_password', l.privacyPassword, secret: true),
      if (privacyKind == 'deletion')
        textField('privacy_confirmation', l.confirmDelete),
      if (privacyKind == 'deletion') note(l.privacyWarning),
      primary(
        l.continueLesson,
        () => run(() async {
          final proof = await api.request(
            'privacy/reauth',
            parent: true,
            data: {
              'purpose': privacyKind,
              'password': field('privacy_password').text,
            },
          );
          field('privacy_password').clear();
          final job = await api.request(
            'privacy/${privacyKind == 'export' ? 'exports' : 'deletions'}',
            parent: true,
            key: const Uuid().v4(),
            data: {
              'reauth_token': proof['reauth_token'],
              'child_id': privacyScope.isEmpty ? null : privacyScope,
              'confirmation': field('privacy_confirmation').text,
            },
          );
          if (privacyKind == 'deletion' && privacyScope.isEmpty) {
            deletionReceipt = Map<String, dynamic>.from(job);
            api.clear();
            child = null;
            session = null;
            children = [];
            lessons = [];
            progress = [];
            selected.clear();
            quote = null;
            consents = {};
            trial = null;
            privacyJobs = [];
            exportText = '';
            for (final c in controllers.values) {
              c.clear();
            }
          } else {
            privacyJobs = await api.request('privacy/jobs', parent: true);
            await family();
          }
        }),
      ),
      secondary(l.refreshJobs, refreshPrivacy),
      ...privacyJobs.map<Widget>(
        (j) => panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${j['kind'] == 'export' ? l.exportData : l.deleteData} · ${jobLabel(j['state'])}',
              ),
              if (j['kind'] == 'export' && j['state'] == 'completed')
                secondary(
                  l.exportData,
                  () => run(() async {
                    final result = await api.request(
                      'privacy/jobs/${j['id']}/download',
                      parent: true,
                    );
                    exportText = const JsonEncoder.withIndent('  ')
                        .convert(result);
                  }),
                ),
            ],
          ),
        ),
      ),
      if (exportText.isNotEmpty)
        panel(
          Column(
            children: [
              SelectableText(exportText),
              secondary(
                l.copyExport,
                () => run(() async {
                  await Clipboard.setData(ClipboardData(text: exportText));
                }),
              ),
            ],
          ),
        ),
      secondary(l.back, () => go('P04')),
    ];
  }

  Future<void> logout() => run(() async {
    try {
      await api.request('auth/logout', parent: true, data: {});
    } finally {
      api.clear();
      child = null;
      session = null;
      children = [];
      lessons = [];
      selected.clear();
      quote = null;
      privacyJobs = [];
      deletionReceipt = null;
      exportText = '';
      for (final c in controllers.values) {
        c.clear();
      }
      go('C01');
    }
  });
}

class Owl extends StatelessWidget {
  const Owl({super.key, this.size = 90});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Сова — учебный помощник',
    image: true,
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _OwlPainter()),
    ),
  );
}

class _OwlPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final paint = Paint();
    paint.color = const Color(0xFFDCE8ED);
    canvas.drawOval(const Rect.fromLTWH(22, 88, 60, 8), paint);
    paint.color = teal;
    canvas.drawOval(const Rect.fromLTWH(17, 20, 66, 67), paint);
    canvas.drawPath(
      Path()
        ..moveTo(23, 35)
        ..lineTo(23, 10)
        ..lineTo(44, 25)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(57, 24)
        ..lineTo(77, 10)
        ..lineTo(77, 34)
        ..close(),
      paint,
    );
    paint.color = const Color(0xFF106775);
    canvas.drawOval(const Rect.fromLTWH(12, 52, 17, 28), paint);
    canvas.drawOval(const Rect.fromLTWH(73, 52, 17, 28), paint);
    paint.color = const Color(0xFF9BD9D5);
    canvas.drawOval(const Rect.fromLTWH(30, 55, 43, 31), paint);
    paint.color = const Color(0xFFFFFEF7);
    canvas.drawCircle(const Offset(37, 43), 18, paint);
    canvas.drawCircle(const Offset(64, 43), 18, paint);
    paint.color = ink;
    canvas.drawCircle(const Offset(38, 44), 3.7, paint);
    canvas.drawCircle(const Offset(62, 44), 3.7, paint);
    paint.color = warm;
    canvas.drawPath(
      Path()
        ..moveTo(44, 56)
        ..lineTo(56, 56)
        ..lineTo(50, 63)
        ..close(),
      paint,
    );
    paint
      ..color = const Color(0xFF75BDBA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(const Rect.fromLTWH(42, 66, 18, 9), 0, 3.14, false, paint);
    paint
      ..color = const Color(0xFFDCA340)
      ..strokeWidth = 3;
    canvas.drawLine(const Offset(40, 85), const Offset(38, 91), paint);
    canvas.drawLine(const Offset(62, 85), const Offset(64, 91), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
