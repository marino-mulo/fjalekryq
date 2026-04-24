import 'package:flutter/foundation.dart';
import '../database/repositories/settings_repository.dart';
import '../database/models/settings_model.dart';

/// Manages user settings (music, sound, notifications).
/// Now backed by SQLite via SettingsRepository.
class SettingsService extends ChangeNotifier {
  final SettingsRepository _repo;
  final int _userId;

  bool _musicEnabled = true;
  bool _soundEnabled = true;
  bool _notificationsEnabled = true;
  bool _emailNotificationsEnabled = true;
  SettingsModel? _model;

  SettingsService(this._repo, this._userId);

  /// Load settings from database. Must be called after construction.
  Future<void> init() async {
    _model = await _repo.getOrCreate(_userId);
    _musicEnabled = _model!.music;
    _soundEnabled = _model!.sound;
    _notificationsEnabled = _model!.notification;
    _emailNotificationsEnabled = _model!.emailNotification;
    notifyListeners();
  }

  bool get musicEnabled => _musicEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get emailNotificationsEnabled => _emailNotificationsEnabled;

  /// Unified "Sounds" state used by the simplified settings UI. True iff
  /// both music and SFX are on — toggling this flips both together so
  /// the user has a single control to mute everything.
  bool get audioEnabled => _musicEnabled && _soundEnabled;

  void toggleAudio() {
    final next = !audioEnabled;
    _musicEnabled = next;
    _soundEnabled = next;
    _saveAll();
    notifyListeners();
  }

  void toggleMusic() {
    _musicEnabled = !_musicEnabled;
    _saveAll();
    notifyListeners();
  }

  void toggleSound() {
    _soundEnabled = !_soundEnabled;
    _saveAll();
    notifyListeners();
  }

  void toggleNotifications() {
    _notificationsEnabled = !_notificationsEnabled;
    _saveAll();
    notifyListeners();
  }

  void toggleEmailNotifications() {
    _emailNotificationsEnabled = !_emailNotificationsEnabled;
    _saveAll();
    notifyListeners();
  }

  void _saveAll() {
    if (_model == null) return;
    _model!.music = _musicEnabled;
    _model!.sound = _soundEnabled;
    _model!.notification = _notificationsEnabled;
    _model!.emailNotification = _emailNotificationsEnabled;
    _repo.saveSettings(_model!);
  }
}
