// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AI Tutor';

  @override
  String get home => 'Home';

  @override
  String get study => 'Learn';

  @override
  String get ask => 'Ask';

  @override
  String get parents => 'For parents';

  @override
  String get welcome => 'Learning made clear.';

  @override
  String get introduction =>
      'I am a learning program. We will explore together, one step at a time.';

  @override
  String get setupAdult => 'Set up with an adult';

  @override
  String get headline => 'What will we learn today?';

  @override
  String get subjects => 'Choose a subject';

  @override
  String get photo => 'Show a task';

  @override
  String get continueLesson => 'Continue';

  @override
  String get startLesson => 'Start lesson';

  @override
  String get login => 'Sign in';

  @override
  String get register => 'Create a family';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get pin => 'Parent PIN';

  @override
  String get family => 'Your family';

  @override
  String get addChild => 'Add a child';

  @override
  String get nickname => 'Nickname';

  @override
  String get grade => 'Grade';

  @override
  String get instructionLanguage => 'Teaching language';

  @override
  String get save => 'Save';

  @override
  String get consents => 'You decide what to allow';

  @override
  String get learningConsent => 'Learning and saved progress';

  @override
  String get voiceConsent => 'Voice';

  @override
  String get photoConsent => 'Task photo';

  @override
  String get researchConsent => 'Research';

  @override
  String get startTrial => 'Try for free';

  @override
  String trialTitle(int days) {
    return 'Try free for $days days';
  }

  @override
  String get trialDetails =>
      'One trial for every family profile. No card or automatic charges.';

  @override
  String get trialActive => 'Trial access is active';

  @override
  String get trialExpired => 'Trial access has ended';

  @override
  String get subscription => 'Subscription';

  @override
  String get quote => 'Calculate price';

  @override
  String get help => 'Hint';

  @override
  String get pause => 'Pause';

  @override
  String get paused => 'Time for a break';

  @override
  String get exit => 'Finish';

  @override
  String get result => 'You did it!';

  @override
  String get savedResult => 'Your result is saved';

  @override
  String get progress => 'Progress';

  @override
  String get unavailable => 'Reviewed materials are being prepared';

  @override
  String get voiceUnavailable =>
      'Voice is not connected yet. You can answer by tapping.';

  @override
  String get photoUnavailable => 'Photo recognition is not connected yet.';

  @override
  String get back => 'Back';

  @override
  String get catalogue => 'Screen catalogue';

  @override
  String get content => 'Learning content';

  @override
  String get tariff => 'Manage pricing';

  @override
  String get offline => 'Check your connection and try again.';

  @override
  String get repeat => 'Try again';

  @override
  String get privacy => 'Data and privacy';

  @override
  String get exportData => 'Export data';

  @override
  String get deleteData => 'Delete data';

  @override
  String get allFamily => 'Whole family';

  @override
  String get confirmDelete => 'Enter DELETE to confirm deletion';

  @override
  String get privacyPassword => 'Enter the adult password again';

  @override
  String get privacyWarning =>
      'Deletion cannot be undone. Access will be revoked. Minimal consent and deletion records are isolated. External backup retention is not yet confirmed.';

  @override
  String get exportNotice =>
      'Exports are available for 24 hours. Passwords, tokens and safety fragments are excluded. Remove downloaded copies from shared devices.';

  @override
  String get refreshJobs => 'Refresh status';

  @override
  String get copyExport => 'Copy JSON';

  @override
  String get queued => 'Queued';

  @override
  String get completed => 'Completed';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get deletionAccepted =>
      'Deletion requested. All family sessions have been revoked.';

  @override
  String get independentTransfer => 'Independent transfer';

  @override
  String get assistedTransfer => 'Assisted transfer';

  @override
  String get hintsCount => 'Hints';

  @override
  String get evidenceNotice =>
      'This is not a school grade. Repeating one example does not establish mastery.';
}
