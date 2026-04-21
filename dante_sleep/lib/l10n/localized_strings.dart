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

  String get exportCsv {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.exportCsv
        : AppStrings.exportCsv;
  }

  String get language {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.language
        : AppStrings.language;
  }

  String get timeFormat {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt'
        ? AppStringsPortuguese.timeFormat
        : AppStrings.timeFormat;
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
}
