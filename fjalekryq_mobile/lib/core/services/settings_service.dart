import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _musicKey = 'fjalekryq_music';
const String _soundKey = 'fjalekryq_sound';
const String _notifKey = 'fjalekryq_notif';
const String _emailNotifKey = 'fjalekryq_email_notif';

/// Manages user settings (music, sound, notifications).
/// Ported from settings-modal.component.ts
class SettingsService extends ChangeNotifier {
  final SharedPreferences _prefs;

  bool _musicEnabled = true;
  bool _soundEnabled = true;
  bool _notificationsEnabled = true;
  bool _emailNotificationsEnabled = true;

  SettingsService(this._prefs) {
    _musicEnabled = _prefs.getBool(_musicKey) ?? true;
    _soundEnabled = _prefs.getBool(_soundKey) ?? true;
    _notificationsEnabled = _prefs.getBool(_notifKey) ?? true;
    _emailNotificationsEnabled = _prefs.getBool(_emailNotifKey) ?? true;
  }

  bool get musicEnabled => _musicEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get emailNotificationsEnabled => _emailNotificationsEnabled;

  void toggleMusic() {
    _musicEnabled = !_musicEnabled;
    _prefs.setBool(_musicKey, _musicEnabled);
    notifyListeners();
  }

  void toggleSound() {
    _soundEnabled = !_soundEnabled;
    _prefs.setBool(_soundKey, _soundEnabled);
    notifyListeners();
  }

  void toggleNotifications() {
    _notificationsEnabled = !_notificationsEnabled;
    _prefs.setBool(_notifKey, _notificationsEnabled);
    notifyListeners();
  }

  void toggleEmailNotifications() {
    _emailNotificationsEnabled = !_emailNotificationsEnabled;
    _prefs.setBool(_emailNotifKey, _emailNotificationsEnabled);
    notifyListeners();
  }
}
