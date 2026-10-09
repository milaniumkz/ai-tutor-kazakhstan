import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_kk.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('kk'),
    Locale('kk', 'KZ'),
    Locale('ru'),
    Locale('ru', 'KZ'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ru_KZ, this message translates to:
  /// **'AI Репетитор'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Главная'**
  String get home;

  /// No description provided for @study.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Учиться'**
  String get study;

  /// No description provided for @ask.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Спросить'**
  String get ask;

  /// No description provided for @parents.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Для родителей'**
  String get parents;

  /// No description provided for @welcome.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Учиться понятно.'**
  String get welcome;

  /// No description provided for @introduction.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Я — программа-помощник. Будем разбираться вместе, шаг за шагом.'**
  String get introduction;

  /// No description provided for @setupAdult.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Настроить со взрослым'**
  String get setupAdult;

  /// No description provided for @headline.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Что узнаем сегодня?'**
  String get headline;

  /// No description provided for @subjects.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Выбрать предмет'**
  String get subjects;

  /// No description provided for @photo.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Показать задание'**
  String get photo;

  /// No description provided for @continueLesson.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Продолжить'**
  String get continueLesson;

  /// No description provided for @startLesson.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Начать занятие'**
  String get startLesson;

  /// No description provided for @login.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Войти'**
  String get login;

  /// No description provided for @register.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Создать семью'**
  String get register;

  /// No description provided for @username.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Логин'**
  String get username;

  /// No description provided for @password.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Пароль'**
  String get password;

  /// No description provided for @pin.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Родительский PIN'**
  String get pin;

  /// No description provided for @family.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Ваша семья'**
  String get family;

  /// No description provided for @addChild.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Добавить ребёнка'**
  String get addChild;

  /// No description provided for @nickname.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Псевдоним'**
  String get nickname;

  /// No description provided for @grade.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Класс'**
  String get grade;

  /// No description provided for @instructionLanguage.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Язык обучения'**
  String get instructionLanguage;

  /// No description provided for @save.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @consents.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Вы решаете, что разрешить'**
  String get consents;

  /// No description provided for @learningConsent.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Обучение и сохранение прогресса'**
  String get learningConsent;

  /// No description provided for @voiceConsent.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Голос'**
  String get voiceConsent;

  /// No description provided for @photoConsent.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Фото задания'**
  String get photoConsent;

  /// No description provided for @researchConsent.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Исследования'**
  String get researchConsent;

  /// No description provided for @startTrial.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Попробовать бесплатно'**
  String get startTrial;

  /// No description provided for @trialTitle.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Бесплатно {days} дн.'**
  String trialTitle(int days);

  /// No description provided for @trialDetails.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Один пробный доступ для всех профилей семьи. Без карты и автосписаний.'**
  String get trialDetails;

  /// No description provided for @trialActive.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Пробный доступ активен'**
  String get trialActive;

  /// No description provided for @trialExpired.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Пробный доступ завершён'**
  String get trialExpired;

  /// No description provided for @subscription.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Подписка'**
  String get subscription;

  /// No description provided for @quote.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Рассчитать стоимость'**
  String get quote;

  /// No description provided for @help.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Подсказка'**
  String get help;

  /// No description provided for @pause.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Пауза'**
  String get pause;

  /// No description provided for @paused.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Можно отдохнуть'**
  String get paused;

  /// No description provided for @exit.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Закончить'**
  String get exit;

  /// No description provided for @result.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Получилось!'**
  String get result;

  /// No description provided for @savedResult.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Результат сохранён'**
  String get savedResult;

  /// No description provided for @progress.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Прогресс'**
  String get progress;

  /// No description provided for @unavailable.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Проверенные материалы ещё готовятся'**
  String get unavailable;

  /// No description provided for @voiceUnavailable.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Голос пока не подключён. Можно ответить касанием.'**
  String get voiceUnavailable;

  /// No description provided for @photoUnavailable.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Распознавание фото пока не подключено.'**
  String get photoUnavailable;

  /// No description provided for @back.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Назад'**
  String get back;

  /// No description provided for @catalogue.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Каталог экранов'**
  String get catalogue;

  /// No description provided for @content.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Учебный контент'**
  String get content;

  /// No description provided for @tariff.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Управление тарифом'**
  String get tariff;

  /// No description provided for @offline.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Проверь соединение и попробуй ещё раз.'**
  String get offline;

  /// No description provided for @repeat.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Повторить'**
  String get repeat;

  /// No description provided for @privacy.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Данные и приватность'**
  String get privacy;

  /// No description provided for @exportData.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Экспорт данных'**
  String get exportData;

  /// No description provided for @deleteData.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Удаление данных'**
  String get deleteData;

  /// No description provided for @allFamily.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Вся семья'**
  String get allFamily;

  /// No description provided for @confirmDelete.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Для удаления введите DELETE'**
  String get confirmDelete;

  /// No description provided for @privacyPassword.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Повторно введите пароль взрослого'**
  String get privacyPassword;

  /// No description provided for @privacyWarning.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Удаление нельзя отменить. Доступ будет отозван. Минимальные журналы согласий и удаления сохраняются отдельно. Сроки внешних резервных копий ещё не подтверждены.'**
  String get privacyWarning;

  /// No description provided for @exportNotice.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Экспорт доступен 24 часа. Пароли, токены и safety-фрагменты не включаются. Удалите скачанную копию с общего устройства.'**
  String get exportNotice;

  /// No description provided for @refreshJobs.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Обновить статусы'**
  String get refreshJobs;

  /// No description provided for @copyExport.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Скопировать JSON'**
  String get copyExport;

  /// No description provided for @queued.
  ///
  /// In ru_KZ, this message translates to:
  /// **'В очереди'**
  String get queued;

  /// No description provided for @completed.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Завершено'**
  String get completed;

  /// No description provided for @cancelled.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Отменено'**
  String get cancelled;

  /// No description provided for @deletionAccepted.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Запрос удаления принят. Все семейные сеансы отозваны.'**
  String get deletionAccepted;

  /// No description provided for @independentTransfer.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Самостоятельный перенос'**
  String get independentTransfer;

  /// No description provided for @assistedTransfer.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Перенос с помощью'**
  String get assistedTransfer;

  /// No description provided for @hintsCount.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Подсказки'**
  String get hintsCount;

  /// No description provided for @evidenceNotice.
  ///
  /// In ru_KZ, this message translates to:
  /// **'Это не школьная оценка. Повтор одного примера не доказывает освоение цели.'**
  String get evidenceNotice;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'kk', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'kk':
      {
        switch (locale.countryCode) {
          case 'KZ':
            return AppLocalizationsKkKz();
        }
        break;
      }
    case 'ru':
      {
        switch (locale.countryCode) {
          case 'KZ':
            return AppLocalizationsRuKz();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'kk':
      return AppLocalizationsKk();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
