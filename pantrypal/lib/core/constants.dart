/// Settings for talking to the backend.
class ApiConfig {
  /// true  = read the sample files in assets/mock/ (no server needed)
  /// false = call the real server at [baseUrl]
  /// Off by default; build with --dart-define=USE_MOCK=true for a phone
  /// install or demo link that has no server to talk to.
  static bool useMock = const bool.fromEnvironment('USE_MOCK');

  /// Windows / web on the same laptop: http://localhost:8000
  /// Android emulator:  http://10.0.2.2:8000
  /// Real phone:        http://<laptop-ip-from-ipconfig>:8000
  static String baseUrl = 'http://localhost:8000';

  static const Duration timeout = Duration(seconds: 15);
}
