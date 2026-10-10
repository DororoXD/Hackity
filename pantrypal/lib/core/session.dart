import 'package:flutter/foundation.dart';

/// Who is signed in. Set by the Login and Sign up screens; widgets that show
/// the name listen to it, so a change shows up straight away.
class Session {
  static final username = ValueNotifier<String>('');
}

/// "Good morning" from 5am, "Good afternoon" from 12pm, "Good evening" from 6pm.
/// Uses the device's clock, not the server's demo date.
String greetingFor(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return 'Good Morning';
  if (h >= 12 && h < 18) return 'Good Afternoon';
  return 'Good Evening';
}
