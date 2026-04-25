import 'package:flutter/material.dart';

import 'app_strings.dart';

class LocalizedStrings {
  final BuildContext context;

  LocalizedStrings(this.context);

  String get appTitle {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.appTitle
        : AppStrings.appTitle;
  }

  String get importCsv {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.importCsv
        : AppStrings.importCsv;
  }

  String get exportCsv {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.exportCsv
        : AppStrings.exportCsv;
  }

  String get showAnalytics {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.showAnalytics
        : AppStrings.showAnalytics;
  }

  String get language {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.language
        : AppStrings.language;
  }

  String get forceVisualTheme {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.forceVisualTheme
        : AppStrings.forceVisualTheme;
  }

  String get visualThemeAuto {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.visualThemeAuto
        : AppStrings.visualThemeAuto;
  }

  String get visualThemeDay {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.visualThemeDay
        : AppStrings.visualThemeDay;
  }

  String get visualThemeNight {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.visualThemeNight
        : AppStrings.visualThemeNight;
  }

  String get timeFormat {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.timeFormat
        : AppStrings.timeFormat;
  }

  String get logout {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.logout
        : AppStrings.logout;
  }

  String get save {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.save
        : AppStrings.save;
  }

  String get userDefaultName {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.userDefaultName
        : AppStrings.userDefaultName;
  }

  String get editName {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.editName
        : AppStrings.editName;
  }

  String get editNameTitle {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.editNameTitle
        : AppStrings.editNameTitle;
  }

  String get nameHint {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.nameHint
        : AppStrings.nameHint;
  }

  String get babyProfile {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.babyProfile
        : AppStrings.babyProfile;
  }

  String get dormiu {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.dormiu
        : AppStrings.dormiu;
  }

  String get acordou {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.acordou
        : AppStrings.acordou;
  }

  String get diaNoite {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.diaNoite
        : AppStrings.diaNoite;
  }

  String get mamou {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.mamou
        : AppStrings.mamou;
  }

  String get didNotFeed {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.didNotFeed
        : AppStrings.didNotFeed;
  }

  String get dayLabel {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.dayLabel
        : AppStrings.dayLabel;
  }

  String get nightLabel {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.nightLabel
        : AppStrings.nightLabel;
  }

  String get cardView {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.cardView
        : AppStrings.cardView;
  }

  String get tableView {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.tableView
        : AppStrings.tableView;
  }

  String get analyticsTitle {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.analyticsTitle
        : AppStrings.analyticsTitle;
  }

  String get filterPeriod {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.filterPeriod
        : AppStrings.filterPeriod;
  }

  String get periodAll {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.periodAll
        : AppStrings.periodAll;
  }

  String get period7Days {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.period7Days
        : AppStrings.period7Days;
  }

  String get period14Days {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.period14Days
        : AppStrings.period14Days;
  }

  String get period30Days {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.period30Days
        : AppStrings.period30Days;
  }

  String get sleepAwakeTrend {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.sleepAwakeTrend
        : AppStrings.sleepAwakeTrend;
  }

  String get dailySleepDistribution {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.dailySleepDistribution
        : AppStrings.dailySleepDistribution;
  }

  String get hoursUnit {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.hoursUnit
        : AppStrings.hoursUnit;
  }

  String get noDataForPeriod {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.noDataForPeriod
        : AppStrings.noDataForPeriod;
  }

  String get lastNightSummary {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.lastNightSummary
        : AppStrings.lastNightSummary;
  }

  String get totalSlept {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.totalSlept
        : AppStrings.totalSlept;
  }

  String get totalAwake {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.totalAwake
        : AppStrings.totalAwake;
  }

  String get wakeUps {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.wakeUps
        : AppStrings.wakeUps;
  }

  String get timesUnit {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.timesUnit
        : AppStrings.timesUnit;
  }

  String get averageSleep {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.averageSleep
        : AppStrings.averageSleep;
  }

  String get averageAwake {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.averageAwake
        : AppStrings.averageAwake;
  }

  String get maxSleep {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.maxSleep
        : AppStrings.maxSleep;
  }

  String get bottleTime {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.bottleTime
        : AppStrings.bottleTime;
  }

  String get noLastNightData {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.noLastNightData
        : AppStrings.noLastNightData;
  }

  String get status {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.status
        : AppStrings.status;
  }

  String get deleteButton {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.deleteButton
        : AppStrings.deleteButton;
  }

  String get cancel {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.cancel
        : AppStrings.cancel;
  }

  String get deleteEntry {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.deleteEntry
        : AppStrings.deleteEntry;
  }

  String get deleteConfirmation {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.deleteConfirmation
        : AppStrings.deleteConfirmation;
  }

  String get selectLanguage {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.selectLanguage
        : AppStrings.selectLanguage;
  }

  String get timeFormatTitle {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.timeFormatTitle
        : AppStrings.timeFormatTitle;
  }

  String get english {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.english
        : AppStrings.english;
  }

  String get portuguese {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.portuguese
        : AppStrings.portuguese;
  }

  String get hourFormat24 {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.hourFormat24
        : AppStrings.hourFormat24;
  }

  String get hourFormat12 {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.hourFormat12
        : AppStrings.hourFormat12;
  }

  String get csvExported {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.csvExported
        : AppStrings.csvExported;
  }

  String get importCancelledOrFailed {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.importCancelledOrFailed
        : AppStrings.importCancelledOrFailed;
  }

  String get entriesImported {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.entriesImported
        : AppStrings.entriesImported;
  }

  String get timeInformation {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.timeInformation
        : AppStrings.timeInformation;
  }

  String get tempoDoricido {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.tempoDoricido
        : AppStrings.tempoDoricido;
  }

  String get tempoAcordado {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.tempoAcordado
        : AppStrings.tempoAcordado;
  }

  String get ok {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.ok
        : AppStrings.ok;
  }

  String get sleptButton {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.sleptButton
        : AppStrings.sleptButton;
  }

  String get wokeUpButton {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.wokeUpButton
        : AppStrings.wokeUpButton;
  }

  String getCsvExportedMessage(String filename) {
    final template = csvExported;
    return template.replaceFirst('{filename}', filename);
  }

  String get authTitleLogin {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.authTitleLogin
        : AppStrings.authTitleLogin;
  }

  String get authTitleRegister {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.authTitleRegister
        : AppStrings.authTitleRegister;
  }

  String get authUserName {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.authUserName
        : AppStrings.authUserName;
  }

  String get authBabyName {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.authBabyName
        : AppStrings.authBabyName;
  }

  String get authEmail {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.authEmail
        : AppStrings.authEmail;
  }

  String get authPassword {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.authPassword
        : AppStrings.authPassword;
  }

  String get authConfirmPassword {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.authConfirmPassword
        : AppStrings.authConfirmPassword;
  }

  String get authSubmitLogin {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.authSubmitLogin
        : AppStrings.authSubmitLogin;
  }

  String get authSubmitRegister {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.authSubmitRegister
        : AppStrings.authSubmitRegister;
  }

  String get authSwitchToRegister {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.authSwitchToRegister
        : AppStrings.authSwitchToRegister;
  }

  String get authSwitchToLogin {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.authSwitchToLogin
        : AppStrings.authSwitchToLogin;
  }

  String get authGoogleSignIn {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.authGoogleSignIn
        : AppStrings.authGoogleSignIn;
  }

  String get authRequired {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.authRequired
        : AppStrings.authRequired;
  }

  String get authInvalidEmail {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.authInvalidEmail
        : AppStrings.authInvalidEmail;
  }

  String get authShortPassword {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.authShortPassword
        : AppStrings.authShortPassword;
  }

  String get authPasswordMismatch {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.authPasswordMismatch
        : AppStrings.authPasswordMismatch;
  }

  String get authInvalidCredentials {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.authInvalidCredentials
        : AppStrings.authInvalidCredentials;
  }

  String get authEmailInUse {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.authEmailInUse
        : AppStrings.authEmailInUse;
  }

  String get authGenericError {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.authGenericError
        : AppStrings.authGenericError;
  }

  String get authFooterHint {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.authFooterHint
        : AppStrings.authFooterHint;
  }

  String getEntriesImportedMessage(int count) {
    final template = entriesImported;
    return template.replaceFirst('{count}', count.toString());
  }

  List<String> getCsvHeaders() {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode == 'pt') {
      return [
        AppStringsPortuguese.csvHeaderSleepTime,
        AppStringsPortuguese.csvHeaderAwakeTime,
        AppStringsPortuguese.csvHeaderWokeUp,
        AppStringsPortuguese.csvHeaderSlept,
        AppStringsPortuguese.csvHeaderPeriod,
        AppStringsPortuguese.csvHeaderBottle,
        AppStringsPortuguese.csvHeaderBottleTime,
      ];
    } else {
      return [
        AppStrings.csvHeaderSleepTime,
        AppStrings.csvHeaderAwakeTime,
        AppStrings.csvHeaderWokeUp,
        AppStrings.csvHeaderSlept,
        AppStrings.csvHeaderPeriod,
        AppStrings.csvHeaderBottle,
        AppStrings.csvHeaderBottleTime,
      ];
    }
  }
}
