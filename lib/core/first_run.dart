import 'package:shared_preferences/shared_preferences.dart';

/// Whether this phone has already been past the Get Started page. Only a brand-new user
/// sees it: after that, no session means the Login page.
class FirstRun {
  FirstRun._();

  static const _key = 'welcome_seen';

  static Future<bool> seen() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  static Future<void> markSeen() async =>
      (await SharedPreferences.getInstance()).setBool(_key, true);
}
