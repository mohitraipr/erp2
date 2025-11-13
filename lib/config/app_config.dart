class AppConfig {
  AppConfig({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  /// Default base URL can be overridden at build time using --dart-define.
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  final String baseUrl;
}
