import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'settings_service.dart';

/// Sound effect identifiers.
enum Sfx {
  tap,
  swap,
  hint,
  solve,
  win,
  lose,
  coin,
  error,
  button,
  levelSelect,
  star,
  dailyClaim,
}

const _sfxFiles = {
  Sfx.tap: 'audio/sfx/tap.wav',
  Sfx.swap: 'audio/sfx/swap.wav',
  Sfx.hint: 'audio/sfx/hint.wav',
  Sfx.solve: 'audio/sfx/solve.wav',
  Sfx.win: 'audio/sfx/win.wav',
  Sfx.lose: 'audio/sfx/lose.wav',
  Sfx.coin: 'audio/sfx/coin.wav',
  Sfx.error: 'audio/sfx/error.wav',
  Sfx.button: 'audio/sfx/button.wav',
  Sfx.levelSelect: 'audio/sfx/level_select.wav',
  Sfx.star: 'audio/sfx/star.wav',
  Sfx.dailyClaim: 'audio/sfx/daily_claim.wav',
};

const _bgMusicFile = 'audio/music/bg_music.wav';

/// Manages all game audio: sound effects and background music.
/// Respects SettingsService toggles for music and sound.
///
/// Replace the placeholder .wav files in assets/audio/ with real audio:
///   sfx/tap.wav        — cell tap / select (~50ms click)
///   sfx/swap.wav       — two cells swapping (~150ms whoosh)
///   sfx/hint.wav       — hint activated (~300ms chime)
///   sfx/solve.wav      — solve word (~500ms magic sparkle)
///   sfx/win.wav        — puzzle complete (~1.5s victory fanfare)
///   sfx/lose.wav       — out of swaps (~800ms sad trombone)
///   sfx/coin.wav       — coins earned (~200ms cha-ching)
///   sfx/error.wav      — insufficient coins (~200ms buzz)
///   sfx/button.wav     — UI button press (~80ms pop)
///   sfx/level_select.wav — level node tap (~100ms click)
///   sfx/star.wav       — star awarded (~300ms twinkle)
///   sfx/daily_claim.wav — daily reward claimed (~500ms reward jingle)
///   music/bg_music.wav — background loop (30-60s ambient track, will loop)
class AudioService {
  final SettingsService _settings;

  // SFX pool — one player per sound to allow overlapping
  final Map<Sfx, AudioPlayer> _sfxPlayers = {};

  // Background music player
  final AudioPlayer _musicPlayer = AudioPlayer();
  bool _musicStarted = false;

  AudioService(this._settings) {
    // Pre-create SFX players
    for (final sfx in Sfx.values) {
      _sfxPlayers[sfx] = AudioPlayer();
    }

    // Configure music player
    _musicPlayer.setReleaseMode(ReleaseMode.loop);
    _musicPlayer.setVolume(0.3);

    // Listen to settings changes
    _settings.addListener(_onSettingsChanged);
  }

  /// Play a sound effect (if sound is enabled).
  void play(Sfx sfx) {
    if (!_settings.soundEnabled) return;
    final player = _sfxPlayers[sfx];
    if (player == null) return;
    final file = _sfxFiles[sfx];
    if (file == null) return;

    player.stop();
    player.play(AssetSource(file));
  }

  /// Start background music (if music is enabled).
  void startMusic() {
    if (!_settings.musicEnabled) return;
    if (_musicStarted) return;
    _musicStarted = true;
    _musicPlayer.play(AssetSource(_bgMusicFile));
  }

  /// Stop background music.
  void stopMusic() {
    _musicStarted = false;
    _musicPlayer.stop();
  }

  /// Pause music (e.g. when app goes to background).
  void pauseMusic() {
    if (_musicStarted) {
      _musicPlayer.pause();
    }
  }

  /// Resume music (e.g. when app comes to foreground).
  void resumeMusic() {
    if (_musicStarted && _settings.musicEnabled) {
      _musicPlayer.resume();
    }
  }

  void _onSettingsChanged() {
    // Music toggled
    if (_settings.musicEnabled && _musicStarted) {
      _musicPlayer.resume();
    } else if (!_settings.musicEnabled) {
      _musicPlayer.pause();
    }
  }

  /// Clean up all players.
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    for (final player in _sfxPlayers.values) {
      player.dispose();
    }
    _musicPlayer.dispose();
  }
}
