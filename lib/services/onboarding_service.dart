import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _keyFirstAppLaunch = 'onboarding_first_app_launch';
  static const String _keyFirstWorkCreation = 'onboarding_first_work_creation';
  static const String _keyFirstWorkOpen = 'onboarding_first_work_open';

  static Future<bool> shouldShowFirstAppLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_keyFirstAppLaunch) ?? false);
  }

  static Future<void> markFirstAppLaunchShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstAppLaunch, true);
  }

  static Future<bool> shouldShowFirstWorkCreation() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_keyFirstWorkCreation) ?? false);
  }

  static Future<void> markFirstWorkCreationShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstWorkCreation, true);
  }

  static Future<bool> shouldShowFirstWorkOpen() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_keyFirstWorkOpen) ?? false);
  }

  static Future<void> markFirstWorkOpenShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstWorkOpen, true);
  }
}
