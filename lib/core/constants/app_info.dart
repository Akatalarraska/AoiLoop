/// Static facts about the application.
///
/// Nothing secret belongs here. Runtime configuration and any future API
/// credentials come from the environment or secure storage — see SECURITY.md.
abstract final class AppInfo {
  /// Keep in sync with `version:` in pubspec.yaml.
  static const String version = '0.1.0-dev';

  /// Filename of the local Drift/SQLite database.
  static const String databaseName = 'blauloop';

  /// Public project home, shown in the about section.
  static const String repositoryUrl =
      'https://github.com/Akatalarraska/BlauLoop';

  /// Supported locales, in the order they are offered to the user.
  /// Adding one means adding an `.arb` file under `lib/l10n/`.
  static const List<String> supportedLanguageCodes = <String>['es', 'en'];
}
