// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'AI Репетитор';

  @override
  String get home => 'Главная';

  @override
  String get study => 'Учиться';

  @override
  String get ask => 'Спросить';

  @override
  String get parents => 'Для родителей';

  @override
  String get welcome => 'Учиться понятно.';

  @override
  String get introduction =>
      'Я — программа-помощник. Будем разбираться вместе, шаг за шагом.';

  @override
  String get setupAdult => 'Настроить со взрослым';

  @override
  String get headline => 'Что узнаем сегодня?';

  @override
  String get subjects => 'Выбрать предмет';

  @override
  String get photo => 'Показать задание';

  @override
  String get continueLesson => 'Продолжить';

  @override
  String get startLesson => 'Начать занятие';

  @override
  String get login => 'Войти';

  @override
  String get register => 'Создать семью';

  @override
  String get username => 'Логин';

  @override
  String get password => 'Пароль';

  @override
  String get pin => 'Родительский PIN';

  @override
  String get family => 'Ваша семья';

  @override
  String get addChild => 'Добавить ребёнка';

  @override
  String get nickname => 'Псевдоним';

  @override
  String get grade => 'Класс';

  @override
  String get instructionLanguage => 'Язык обучения';

  @override
  String get save => 'Сохранить';

  @override
  String get consents => 'Вы решаете, что разрешить';

  @override
  String get learningConsent => 'Обучение и сохранение прогресса';

  @override
  String get voiceConsent => 'Голос';

  @override
  String get photoConsent => 'Фото задания';

  @override
  String get researchConsent => 'Исследования';

  @override
  String get startTrial => 'Попробовать бесплатно';

  @override
  String trialTitle(int days) {
    return 'Бесплатно $days дн.';
  }

  @override
  String get trialDetails =>
      'Один пробный доступ для всех профилей семьи. Без карты и автосписаний.';

  @override
  String get trialActive => 'Пробный доступ активен';

  @override
  String get trialExpired => 'Пробный доступ завершён';

  @override
  String get subscription => 'Подписка';

  @override
  String get quote => 'Рассчитать стоимость';

  @override
  String get help => 'Подсказка';

  @override
  String get pause => 'Пауза';

  @override
  String get paused => 'Можно отдохнуть';

  @override
  String get exit => 'Закончить';

  @override
  String get result => 'Получилось!';

  @override
  String get savedResult => 'Результат сохранён';

  @override
  String get progress => 'Прогресс';

  @override
  String get unavailable => 'Проверенные материалы ещё готовятся';

  @override
  String get voiceUnavailable =>
      'Голос пока не подключён. Можно ответить касанием.';

  @override
  String get photoUnavailable => 'Распознавание фото пока не подключено.';

  @override
  String get back => 'Назад';

  @override
  String get catalogue => 'Каталог экранов';

  @override
  String get content => 'Учебный контент';

  @override
  String get tariff => 'Управление тарифом';

  @override
  String get offline => 'Проверь соединение и попробуй ещё раз.';

  @override
  String get repeat => 'Повторить';

  @override
  String get privacy => 'Данные и приватность';

  @override
  String get exportData => 'Экспорт данных';

  @override
  String get deleteData => 'Удаление данных';

  @override
  String get allFamily => 'Вся семья';

  @override
  String get confirmDelete => 'Для удаления введите DELETE';

  @override
  String get privacyPassword => 'Повторно введите пароль взрослого';

  @override
  String get privacyWarning =>
      'Удаление нельзя отменить. Доступ будет отозван. Минимальные журналы согласий и удаления сохраняются отдельно. Сроки внешних резервных копий ещё не подтверждены.';

  @override
  String get exportNotice =>
      'Экспорт доступен 24 часа. Пароли, токены и safety-фрагменты не включаются. Удалите скачанную копию с общего устройства.';

  @override
  String get refreshJobs => 'Обновить статусы';

  @override
  String get copyExport => 'Скопировать JSON';

  @override
  String get queued => 'В очереди';

  @override
  String get completed => 'Завершено';

  @override
  String get cancelled => 'Отменено';

  @override
  String get deletionAccepted =>
      'Запрос удаления принят. Все семейные сеансы отозваны.';

  @override
  String get independentTransfer => 'Самостоятельный перенос';

  @override
  String get assistedTransfer => 'Перенос с помощью';

  @override
  String get hintsCount => 'Подсказки';

  @override
  String get evidenceNotice =>
      'Это не школьная оценка. Повтор одного примера не доказывает освоение цели.';
}

/// The translations for Russian, as used in Kazakhstan (`ru_KZ`).
class AppLocalizationsRuKz extends AppLocalizationsRu {
  AppLocalizationsRuKz() : super('ru_KZ');

  @override
  String get appTitle => 'AI Репетитор';

  @override
  String get home => 'Главная';

  @override
  String get study => 'Учиться';

  @override
  String get ask => 'Спросить';

  @override
  String get parents => 'Для родителей';

  @override
  String get welcome => 'Учиться понятно.';

  @override
  String get introduction =>
      'Я — программа-помощник. Будем разбираться вместе, шаг за шагом.';

  @override
  String get setupAdult => 'Настроить со взрослым';

  @override
  String get headline => 'Что узнаем сегодня?';

  @override
  String get subjects => 'Выбрать предмет';

  @override
  String get photo => 'Показать задание';

  @override
  String get continueLesson => 'Продолжить';

  @override
  String get startLesson => 'Начать занятие';

  @override
  String get login => 'Войти';

  @override
  String get register => 'Создать семью';

  @override
  String get username => 'Логин';

  @override
  String get password => 'Пароль';

  @override
  String get pin => 'Родительский PIN';

  @override
  String get family => 'Ваша семья';

  @override
  String get addChild => 'Добавить ребёнка';

  @override
  String get nickname => 'Псевдоним';

  @override
  String get grade => 'Класс';

  @override
  String get instructionLanguage => 'Язык обучения';

  @override
  String get save => 'Сохранить';

  @override
  String get consents => 'Вы решаете, что разрешить';

  @override
  String get learningConsent => 'Обучение и сохранение прогресса';

  @override
  String get voiceConsent => 'Голос';

  @override
  String get photoConsent => 'Фото задания';

  @override
  String get researchConsent => 'Исследования';

  @override
  String get startTrial => 'Попробовать бесплатно';

  @override
  String trialTitle(int days) {
    return 'Бесплатно $days дн.';
  }

  @override
  String get trialDetails =>
      'Один пробный доступ для всех профилей семьи. Без карты и автосписаний.';

  @override
  String get trialActive => 'Пробный доступ активен';

  @override
  String get trialExpired => 'Пробный доступ завершён';

  @override
  String get subscription => 'Подписка';

  @override
  String get quote => 'Рассчитать стоимость';

  @override
  String get help => 'Подсказка';

  @override
  String get pause => 'Пауза';

  @override
  String get paused => 'Можно отдохнуть';

  @override
  String get exit => 'Закончить';

  @override
  String get result => 'Получилось!';

  @override
  String get savedResult => 'Результат сохранён';

  @override
  String get progress => 'Прогресс';

  @override
  String get unavailable => 'Проверенные материалы ещё готовятся';

  @override
  String get voiceUnavailable =>
      'Голос пока не подключён. Можно ответить касанием.';

  @override
  String get photoUnavailable => 'Распознавание фото пока не подключено.';

  @override
  String get back => 'Назад';

  @override
  String get catalogue => 'Каталог экранов';

  @override
  String get content => 'Учебный контент';

  @override
  String get tariff => 'Управление тарифом';

  @override
  String get offline => 'Проверь соединение и попробуй ещё раз.';

  @override
  String get repeat => 'Повторить';

  @override
  String get privacy => 'Данные и приватность';

  @override
  String get exportData => 'Экспорт данных';

  @override
  String get deleteData => 'Удаление данных';

  @override
  String get allFamily => 'Вся семья';

  @override
  String get confirmDelete => 'Для удаления введите DELETE';

  @override
  String get privacyPassword => 'Повторно введите пароль взрослого';

  @override
  String get privacyWarning =>
      'Удаление нельзя отменить. Доступ будет отозван. Минимальные журналы согласий и удаления сохраняются отдельно. Сроки внешних резервных копий ещё не подтверждены.';

  @override
  String get exportNotice =>
      'Экспорт доступен 24 часа. Пароли, токены и safety-фрагменты не включаются. Удалите скачанную копию с общего устройства.';

  @override
  String get refreshJobs => 'Обновить статусы';

  @override
  String get copyExport => 'Скопировать JSON';

  @override
  String get queued => 'В очереди';

  @override
  String get completed => 'Завершено';

  @override
  String get cancelled => 'Отменено';

  @override
  String get deletionAccepted =>
      'Запрос удаления принят. Все семейные сеансы отозваны.';

  @override
  String get independentTransfer => 'Самостоятельный перенос';

  @override
  String get assistedTransfer => 'Перенос с помощью';

  @override
  String get hintsCount => 'Подсказки';

  @override
  String get evidenceNotice =>
      'Это не школьная оценка. Повтор одного примера не доказывает освоение цели.';
}
