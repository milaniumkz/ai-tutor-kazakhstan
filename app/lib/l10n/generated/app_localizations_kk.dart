// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kazakh (`kk`).
class AppLocalizationsKk extends AppLocalizations {
  AppLocalizationsKk([String locale = 'kk']) : super(locale);

  @override
  String get appTitle => 'AI Репетитор';

  @override
  String get home => 'Басты бет';

  @override
  String get study => 'Оқу';

  @override
  String get ask => 'Сұрау';

  @override
  String get parents => 'Ата-аналарға';

  @override
  String get welcome => 'Түсінікті оқу.';

  @override
  String get introduction =>
      'Мен — көмекші бағдарлама. Бірге қадамдап үйренеміз.';

  @override
  String get setupAdult => 'Ересекпен бірге баптау';

  @override
  String get headline => 'Бүгін не үйренеміз?';

  @override
  String get subjects => 'Пәнді таңдау';

  @override
  String get photo => 'Тапсырманы көрсету';

  @override
  String get continueLesson => 'Жалғастыру';

  @override
  String get startLesson => 'Сабақты бастау';

  @override
  String get login => 'Кіру';

  @override
  String get register => 'Отбасын құру';

  @override
  String get username => 'Логин';

  @override
  String get password => 'Құпиясөз';

  @override
  String get pin => 'Ата-ананың PIN коды';

  @override
  String get family => 'Сіздің отбасыңыз';

  @override
  String get addChild => 'Баланы қосу';

  @override
  String get nickname => 'Бүркеншік ат';

  @override
  String get grade => 'Сынып';

  @override
  String get instructionLanguage => 'Оқу тілі';

  @override
  String get save => 'Сақтау';

  @override
  String get consents => 'Не рұқсат етілетінін өзіңіз шешесіз';

  @override
  String get learningConsent => 'Оқу және нәтижені сақтау';

  @override
  String get voiceConsent => 'Дауыс';

  @override
  String get photoConsent => 'Тапсырманың фотосы';

  @override
  String get researchConsent => 'Зерттеулер';

  @override
  String get startTrial => 'Тегін байқап көру';

  @override
  String trialTitle(int days) {
    return '$days күн тегін';
  }

  @override
  String get trialDetails =>
      'Отбасының барлық профиліне бір сынақ мерзімі. Карта және автоматты төлем жоқ.';

  @override
  String get trialActive => 'Сынақ мерзімі белсенді';

  @override
  String get trialExpired => 'Сынақ мерзімі аяқталды';

  @override
  String get subscription => 'Жазылым';

  @override
  String get quote => 'Бағаны есептеу';

  @override
  String get help => 'Көмек';

  @override
  String get pause => 'Үзіліс';

  @override
  String get paused => 'Демалуға болады';

  @override
  String get exit => 'Аяқтау';

  @override
  String get result => 'Жарайсың!';

  @override
  String get savedResult => 'Нәтиже сақталды';

  @override
  String get progress => 'Нәтижелер';

  @override
  String get unavailable => 'Тексерілген материалдар дайындалып жатыр';

  @override
  String get voiceUnavailable =>
      'Дауыс әлі қосылмаған. Жауапты түрту арқылы таңдауға болады.';

  @override
  String get photoUnavailable => 'Фотодан тану әлі қосылмаған.';

  @override
  String get back => 'Артқа';

  @override
  String get catalogue => 'Экрандар каталогы';

  @override
  String get content => 'Оқу материалдары';

  @override
  String get tariff => 'Тарифті басқару';

  @override
  String get offline => 'Байланысты тексеріп, қайта байқап көр.';

  @override
  String get repeat => 'Қайталау';

  @override
  String get privacy => 'Деректер және құпиялылық';

  @override
  String get exportData => 'Деректерді экспорттау';

  @override
  String get deleteData => 'Деректерді жою';

  @override
  String get allFamily => 'Бүкіл отбасы';

  @override
  String get confirmDelete => 'Жою үшін DELETE енгізіңіз';

  @override
  String get privacyPassword => 'Ересектің құпиясөзін қайта енгізіңіз';

  @override
  String get privacyWarning =>
      'Жоюды қайтару мүмкін емес. Қолжетімділік тоқтатылады. Келісім мен жою журналдары бөлек сақталады. Сыртқы резервтік көшірмелердің мерзімі әлі расталмаған.';

  @override
  String get exportNotice =>
      'Экспорт 24 сағат қолжетімді. Құпиясөздер, токендер және қауіпсіздік үзінділері қосылмайды. Жүктелген көшірмені ортақ құрылғыдан жойыңыз.';

  @override
  String get refreshJobs => 'Күйлерді жаңарту';

  @override
  String get copyExport => 'JSON көшіру';

  @override
  String get queued => 'Кезекте';

  @override
  String get completed => 'Аяқталды';

  @override
  String get cancelled => 'Болдырылмады';

  @override
  String get deletionAccepted =>
      'Жою сұрауы қабылданды. Отбасының барлық сеанстары тоқтатылды.';

  @override
  String get independentTransfer => 'Өз бетімен орындау';

  @override
  String get assistedTransfer => 'Көмекпен орындау';

  @override
  String get hintsCount => 'Кеңестер';

  @override
  String get evidenceNotice =>
      'Бұл мектеп бағасы емес. Бір мысалды қайталау мақсатты меңгеруді дәлелдемейді.';
}

/// The translations for Kazakh, as used in Kazakhstan (`kk_KZ`).
class AppLocalizationsKkKz extends AppLocalizationsKk {
  AppLocalizationsKkKz() : super('kk_KZ');

  @override
  String get appTitle => 'AI Репетитор';

  @override
  String get home => 'Басты бет';

  @override
  String get study => 'Оқу';

  @override
  String get ask => 'Сұрау';

  @override
  String get parents => 'Ата-аналарға';

  @override
  String get welcome => 'Түсінікті оқу.';

  @override
  String get introduction =>
      'Мен — көмекші бағдарлама. Бірге қадамдап үйренеміз.';

  @override
  String get setupAdult => 'Ересекпен бірге баптау';

  @override
  String get headline => 'Бүгін не үйренеміз?';

  @override
  String get subjects => 'Пәнді таңдау';

  @override
  String get photo => 'Тапсырманы көрсету';

  @override
  String get continueLesson => 'Жалғастыру';

  @override
  String get startLesson => 'Сабақты бастау';

  @override
  String get login => 'Кіру';

  @override
  String get register => 'Отбасын құру';

  @override
  String get username => 'Логин';

  @override
  String get password => 'Құпиясөз';

  @override
  String get pin => 'Ата-ананың PIN коды';

  @override
  String get family => 'Сіздің отбасыңыз';

  @override
  String get addChild => 'Баланы қосу';

  @override
  String get nickname => 'Бүркеншік ат';

  @override
  String get grade => 'Сынып';

  @override
  String get instructionLanguage => 'Оқу тілі';

  @override
  String get save => 'Сақтау';

  @override
  String get consents => 'Не рұқсат етілетінін өзіңіз шешесіз';

  @override
  String get learningConsent => 'Оқу және нәтижені сақтау';

  @override
  String get voiceConsent => 'Дауыс';

  @override
  String get photoConsent => 'Тапсырманың фотосы';

  @override
  String get researchConsent => 'Зерттеулер';

  @override
  String get startTrial => 'Тегін байқап көру';

  @override
  String trialTitle(int days) {
    return '$days күн тегін';
  }

  @override
  String get trialDetails =>
      'Отбасының барлық профиліне бір сынақ мерзімі. Карта және автоматты төлем жоқ.';

  @override
  String get trialActive => 'Сынақ мерзімі белсенді';

  @override
  String get trialExpired => 'Сынақ мерзімі аяқталды';

  @override
  String get subscription => 'Жазылым';

  @override
  String get quote => 'Бағаны есептеу';

  @override
  String get help => 'Көмек';

  @override
  String get pause => 'Үзіліс';

  @override
  String get paused => 'Демалуға болады';

  @override
  String get exit => 'Аяқтау';

  @override
  String get result => 'Жарайсың!';

  @override
  String get savedResult => 'Нәтиже сақталды';

  @override
  String get progress => 'Нәтижелер';

  @override
  String get unavailable => 'Тексерілген материалдар дайындалып жатыр';

  @override
  String get voiceUnavailable =>
      'Дауыс әлі қосылмаған. Жауапты түрту арқылы таңдауға болады.';

  @override
  String get photoUnavailable => 'Фотодан тану әлі қосылмаған.';

  @override
  String get back => 'Артқа';

  @override
  String get catalogue => 'Экрандар каталогы';

  @override
  String get content => 'Оқу материалдары';

  @override
  String get tariff => 'Тарифті басқару';

  @override
  String get offline => 'Байланысты тексеріп, қайта байқап көр.';

  @override
  String get repeat => 'Қайталау';

  @override
  String get privacy => 'Деректер және құпиялылық';

  @override
  String get exportData => 'Деректерді экспорттау';

  @override
  String get deleteData => 'Деректерді жою';

  @override
  String get allFamily => 'Бүкіл отбасы';

  @override
  String get confirmDelete => 'Жою үшін DELETE енгізіңіз';

  @override
  String get privacyPassword => 'Ересектің құпиясөзін қайта енгізіңіз';

  @override
  String get privacyWarning =>
      'Жоюды қайтару мүмкін емес. Қолжетімділік тоқтатылады. Келісім мен жою журналдары бөлек сақталады. Сыртқы резервтік көшірмелердің мерзімі әлі расталмаған.';

  @override
  String get exportNotice =>
      'Экспорт 24 сағат қолжетімді. Құпиясөздер, токендер және қауіпсіздік үзінділері қосылмайды. Жүктелген көшірмені ортақ құрылғыдан жойыңыз.';

  @override
  String get refreshJobs => 'Күйлерді жаңарту';

  @override
  String get copyExport => 'JSON көшіру';

  @override
  String get queued => 'Кезекте';

  @override
  String get completed => 'Аяқталды';

  @override
  String get cancelled => 'Болдырылмады';

  @override
  String get deletionAccepted =>
      'Жою сұрауы қабылданды. Отбасының барлық сеанстары тоқтатылды.';

  @override
  String get independentTransfer => 'Өз бетімен орындау';

  @override
  String get assistedTransfer => 'Көмекпен орындау';

  @override
  String get hintsCount => 'Кеңестер';

  @override
  String get evidenceNotice =>
      'Бұл мектеп бағасы емес. Бір мысалды қайталау мақсатты меңгеруді дәлелдемейді.';
}
