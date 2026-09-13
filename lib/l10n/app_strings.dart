class AppStrings {
  static const String appTitle = 'Dante Sleep';

  // Menu items
  static const String importCsv = 'Import CSV';
  static const String exportCsv = 'Export CSV';
  static const String showAnalytics = 'Sleep Insights';
  static const String language = 'Language';
    static const String forceVisualTheme = 'Force visual theme';
    static const String visualThemeAuto = 'Auto';
    static const String visualThemeDay = 'Day';
    static const String visualThemeNight = 'Night';
  static const String timeFormat = 'Time Format';
  static const String logout = 'Logout';
  static const String save = 'Save';
  static const String userDefaultName = 'User';
  static const String editName = 'Edit name';
  static const String editNameTitle = 'Edit Name';
  static const String nameHint = 'Name';
  static const String babyProfile = 'Baby Profile';

  // Table headers
  static const String dormiu = 'Slept';
  static const String acordou = 'Woke Up';
  static const String diaNoite = 'Day/Night';
  static const String mamou = 'Fed';
  static const String status = 'Status';

  // Buttons
  static const String deleteButton = 'Delete Card';
  static const String shareButton = 'Share';
  static const String estimatedWakeUp = 'Should wake up starting from';
  static const String estimatedNextSleep = 'Should sleep again starting from';
  static const String bridgeNapQuestionTitle = 'Bridge nap?';
  static const String bridgeNapQuestionBody =
      'This nap started between 4 PM and 6 PM. Is it a short bridge nap (cat nap)?';
  static const String yesLabel = 'Yes';
  static const String noLabel = 'No';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String ok = 'OK';
  static const String sleptButton = 'Slept';
  static const String wokeUpButton = 'Woke Up';

  // Dialogs
  static const String avgSleep = 'Average Sleep';
  static const String avgAwake = 'Average Awake';
  static const String deleteEntry = 'Delete Entry';
  static const String deleteConfirmation =
      'Are you sure you want to delete this entry? This action cannot be undone.';
  static const String selectLanguage = 'Select Language';
  static const String timeFormatTitle = 'Time Format';
  static const String english = 'English';
  static const String portuguese = 'Portuguese';
  static const String hourFormat24 = '24 Hour';
  static const String hourFormat12 = '12 Hour';
  static const String csvExported = 'CSV exported: {filename}';
  static const String importCancelledOrFailed = 'Import cancelled or failed';
  static const String entriesImported = '{count} entries imported';

  // Time information
  static const String timeInformation = 'Time Information';
  static const String tempoDoricido = 'Sleep Time';
  static const String tempoAcordado = 'Awake Time';

  // CSV Export headers
  static const String csvHeaderSleepTime = 'Sleep Time';
  static const String csvHeaderAwakeTime = 'Awake Time';
  static const String csvHeaderWokeUp = 'Woke Up';
  static const String csvHeaderSlept = 'Slept';
  static const String csvHeaderPeriod = 'Period';
  static const String csvHeaderBottle = 'Bottle';
  static const String csvHeaderBottleTime = 'Bottle Time';
  static const String csvValueDay = 'Day';
  static const String csvValueNight = 'Night';
  static const String csvValueYes = 'Yes';
  static const String csvValueNo = 'No';
  static const String dayLabel = 'Day';
  static const String nightLabel = 'Night';
  static const String didNotFeed = 'Did not feed';
  static const String cardView = 'Card view';
  static const String tableView = 'Table view';
  static const String analyticsTitle = 'Sleep Insights';
  static const String filterPeriod = 'Period';
  static const String periodAll = 'All';
  static const String period7Days = 'Last 7 days';
  static const String period14Days = 'Last 14 days';
  static const String period30Days = 'Last 30 days';
  static const String sleepAwakeTrend = 'Sleep vs awake trend';
  static const String dailySleepDistribution = 'Daily sleep distribution';
  static const String hoursUnit = 'h';
  static const String noDataForPeriod = 'No data for selected period';
  static const String lastNightSummary = 'Summary of Night';
  static const String totalSlept = 'Total Slept';
  static const String totalAwake = 'Total Awake';
  static const String wakeUps = 'Woke up';
  static const String averageSleep = 'Avg Sleep';
  static const String averageAwake = 'Avg Awake';
  static const String maxSleep = 'Max Sleep';
  static const String noLastNightData = 'No night data available yet';
  static const String bottleTime = 'Bottle Time';
  static const String timesUnit = 'times';

  // Auth
  static const String authTitleLogin = 'Sign in';
  static const String authTitleRegister = 'Create account';
  static const String authUserName = 'Your name';
  static const String authBabyName = 'Baby name';
  static const String authEmail = 'Email';
  static const String authPassword = 'Password';
  static const String authConfirmPassword = 'Confirm password';
  static const String authSubmitLogin = 'Sign in';
  static const String authSubmitRegister = 'Sign up';
  static const String authSwitchToRegister = 'No account yet? Create one';
  static const String authSwitchToLogin = 'Already have an account? Sign in';
  static const String authGoogleSignIn = 'Continue with Google';
  static const String authRequired = 'Required field';
  static const String authInvalidEmail = 'Invalid email';
  static const String authShortPassword =
      'Password must have at least 6 characters';
  static const String authPasswordMismatch = 'Passwords do not match';
  static const String authInvalidCredentials = 'Invalid email or password';
  static const String authEmailInUse = 'This email is already in use';
  static const String authGenericError =
      'Could not authenticate. Please try again.';
  static const String authFooterHint = 'Use email and password to continue.';

  // Account linking (settings)
  static const String settingsLinkGoogleTitle = 'Link Google account';
  static const String settingsLinkGoogleSubtitle =
      'Also sign in using your Google account';
  static const String settingsAddEmailPasswordTitle =
      'Add email & password login';
  static const String settingsAddEmailPasswordSubtitle =
      'Create a password to also sign in without Google';
  static const String linkEmailScreenTitle = 'Add email and password';
  static const String passwordStrengthHint =
      'At least 6 characters, with an uppercase letter, a number and a special character.';
  static const String passwordWeak =
      'Password must have an uppercase letter, a number and a special character.';
  static const String linkGoogleSuccess =
      'Google account linked successfully!';
  static const String linkEmailSuccess =
      'Email login added! You can now sign in with either method.';
  static const String linkErrorEmailInUse =
      'This account is already linked to another user.';
  static const String linkErrorRequiresRecentLogin =
      'For security, please sign in again before linking accounts.';
  static const String linkErrorGeneric =
      'Could not link the account. Please try again.';
}

class AppStringsPortuguese {
  static const String appTitle = 'Dante Sleep';

  // Menu items
  static const String importCsv = 'Importar CSV';
  static const String exportCsv = 'Exportar CSV';
  static const String showAnalytics = 'Ver Evolução';
  static const String language = 'Idioma';
    static const String forceVisualTheme = 'Forçar tema visual';
    static const String visualThemeAuto = 'Auto';
    static const String visualThemeDay = 'Dia';
    static const String visualThemeNight = 'Noite';
  static const String timeFormat = 'Formato de Hora';
  static const String logout = 'Sair';
  static const String save = 'Salvar';
  static const String userDefaultName = 'Usuário';
  static const String editName = 'Editar nome';
  static const String editNameTitle = 'Editar Nome';
  static const String nameHint = 'Nome';
  static const String babyProfile = 'Perfil do Bebê';

  // Table headers
  static const String dormiu = 'Dormiu';
  static const String acordou = 'Acordou';
  static const String diaNoite = 'Dia/Noite';
  static const String mamou = 'Mamou';
  static const String status = 'Status';

  // Buttons
  static const String deleteButton = 'Deletar Card';
  static const String shareButton = 'Compartilhar';
  static const String estimatedWakeUp = 'Deverá acordar a partir de';
  static const String estimatedNextSleep = 'Deverá dormir novamente a partir de';
  static const String bridgeNapQuestionTitle = 'Soneca ponte?';
  static const String bridgeNapQuestionBody =
      'Essa soneca começou entre 16h e 18h. É uma soneca ponte curta (cat nap)?';
  static const String yesLabel = 'Sim';
  static const String noLabel = 'Não';
  static const String cancel = 'Cancelar';
  static const String confirm = 'Confirmar';
  static const String ok = 'OK';
  static const String sleptButton = 'Dormiu';
  static const String wokeUpButton = 'Acordou';

  // Dialogs
  static const String deleteEntry = 'Deletar Entrada';
  static const String deleteConfirmation =
      'Tem certeza que deseja deletar esta entrada? Esta ação não pode ser desfeita.';
  static const String selectLanguage = 'Selecionar Idioma';
  static const String timeFormatTitle = 'Formato de Hora';
  static const String english = 'Inglês';
  static const String portuguese = 'Português';
  static const String hourFormat24 = '24 Horas';
  static const String hourFormat12 = '12 Horas';
  static const String csvExported = 'CSV exportado: {filename}';
  static const String importCancelledOrFailed =
      'Importação cancelada ou falhou';
  static const String entriesImported = '{count} registros importados';

  // Time information
  static const String timeInformation = 'Informações de Tempo';
  static const String tempoDoricido = 'Tempo Dormindo';
  static const String tempoAcordado = 'Tempo Acordado';

  // CSV Export headers
  static const String csvHeaderSleepTime = 'Tempo Dormindo';
  static const String csvHeaderAwakeTime = 'Tempo Acordado';
  static const String csvHeaderWokeUp = 'Acordou';
  static const String csvHeaderSlept = 'Dormiu';
  static const String csvHeaderPeriod = 'Período';
  static const String csvHeaderBottle = 'Mamou';
  static const String csvHeaderBottleTime = 'Hora da Mamada';
  static const String csvValueDay = 'Dia';
  static const String csvValueNight = 'Noite';
  static const String csvValueYes = 'Sim';
  static const String csvValueNo = 'Não';
  static const String dayLabel = 'Dia';
  static const String nightLabel = 'Noite';
  static const String didNotFeed = 'Não Mamou';
  static const String cardView = 'Visão em cards';
  static const String tableView = 'Visão em tabela';
  static const String analyticsTitle = 'Evolução do Sono';
  static const String filterPeriod = 'Período';
  static const String periodAll = 'Tudo';
  static const String period7Days = 'Últimos 7 dias';
  static const String period14Days = 'Últimos 14 dias';
  static const String period30Days = 'Últimos 30 dias';
  static const String sleepAwakeTrend = 'Sono x acordado';
  static const String dailySleepDistribution = 'Distribuição diária de sono';
  static const String hoursUnit = 'h';
  static const String noDataForPeriod = 'Sem dados para o período selecionado';
  static const String lastNightSummary = 'Resumo da noite de';
  static const String totalSlept = 'Total Dormido';
  static const String totalAwake = 'Total Acordado';
  static const String wakeUps = 'Acordou';
  static const String averageSleep = 'Média de tempo dormindo';
  static const String averageAwake = 'Média de tempo acordado';
  static const String maxSleep = 'Máximo tempo dormindo';
  static const String noLastNightData = 'Sem dados de noite ainda';
  static const String bottleTime = 'Hora da Mamada';
  static const String timesUnit = 'vezes';

  // Auth
  static const String authTitleLogin = 'Entrar';
  static const String authTitleRegister = 'Criar conta';
  static const String authUserName = 'Seu nome';
  static const String authBabyName = 'Nome do bebê';
  static const String authEmail = 'E-mail';
  static const String authPassword = 'Senha';
  static const String authConfirmPassword = 'Confirmar senha';
  static const String authSubmitLogin = 'Entrar';
  static const String authSubmitRegister = 'Cadastrar';
  static const String authSwitchToRegister = 'Não tem conta? Cadastre-se';
  static const String authSwitchToLogin = 'Já tem conta? Entrar';
  static const String authGoogleSignIn = 'Entrar com Google';
  static const String authRequired = 'Campo obrigatório';
  static const String authInvalidEmail = 'E-mail inválido';
  static const String authShortPassword =
      'Senha deve ter pelo menos 6 caracteres';
  static const String authPasswordMismatch = 'As senhas não coincidem';
  static const String authInvalidCredentials = 'E-mail ou senha inválidos';
  static const String authEmailInUse = 'Este e-mail já está em uso';
  static const String authGenericError =
      'Não foi possível autenticar. Tente novamente.';
  static const String authFooterHint = 'Use e-mail e senha para acessar.';

  // Account linking (settings)
  static const String settingsLinkGoogleTitle = 'Vincular conta Google';
  static const String settingsLinkGoogleSubtitle =
      'Acesse também com sua conta Google';
  static const String settingsAddEmailPasswordTitle =
      'Adicionar login com e-mail e senha';
  static const String settingsAddEmailPasswordSubtitle =
      'Crie uma senha para acessar também sem o Google';
  static const String linkEmailScreenTitle = 'Adicionar e-mail e senha';
  static const String passwordStrengthHint =
      'Mínimo de 6 caracteres, com letra maiúscula, número e caractere especial.';
  static const String passwordWeak =
      'A senha deve ter letra maiúscula, número e caractere especial.';
  static const String linkGoogleSuccess =
      'Conta Google vinculada com sucesso!';
  static const String linkEmailSuccess =
      'Login por e-mail adicionado! Agora você pode entrar com qualquer um dos métodos.';
  static const String linkErrorEmailInUse =
      'Esta conta já está vinculada a outro usuário.';
  static const String linkErrorRequiresRecentLogin =
      'Por segurança, faça login novamente antes de vincular contas.';
  static const String linkErrorGeneric =
      'Não foi possível vincular a conta. Tente novamente.';
}
