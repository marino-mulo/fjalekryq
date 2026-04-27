import 'package:audioplayers/audioplayers.dart';
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
  Sfx.dailyClaim: 'audio/sfx/daily_claim.wav',
};

/// Set this to true once you replace the placeholder .wav files with real audio.
/// While false, ALL audio playback is skipped to avoid main-thread jank
/// caused by audioplayers trying to decode empty placeholder files.
///
/// Background music has been removed from the app — only short SFX
/// remain. The settings sheet exposes a single "Zëri" (sound) toggle
/// that controls these effects.
const bool _audioReady = true;

class AudioService {
  final SettingsService _settings;

  // SFX pool — created lazily on first use
  final Map<Sfx, AudioPlayer> _sfxPlayers = {};

  AudioService(this._settings);

  AudioPlayer _getSfxPlayer(Sfx sfx) {
    return _sfxPlayers.putIfAbsent(sfx, () => AudioPlayer());
  }

  /// Play a sound effect (if sound is enabled).
  void play(Sfx sfx) {
    if (!_audioReady) return;  // Skip while using placeholder files
    if (!_settings.soundEnabled) return;
    final file = _sfxFiles[sfx];
    if (file == null) return;

    final player = _getSfxPlayer(sfx);
    player.stop();
    player.play(AssetSource(file));
  }

  /// Clean up all players.
  void dispose() {
    for (final player in _sfxPlayers.values) {
      player.dispose();
    }
  }
}
