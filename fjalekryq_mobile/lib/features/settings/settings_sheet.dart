import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/database/models/user_model.dart';
import '../../core/database/repositories/user_repository.dart';
import '../../core/services/coin_service.dart';
import '../../core/services/settings_service.dart';
import '../../shared/constants/theme.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../game/game_screen.dart';
import '../legal/privacy_policy_screen.dart';

const int _nicknameCost = 100;
const int _nicknameMinLength = 6;
const int _nicknameMaxLength = 12;

const _avatarOptions = [
  (color: Color(0xFF22C55E), icon: Icons.person_rounded),
  (color: Color(0xFFF4B400), icon: Icons.person_rounded),
  (color: Color(0xFF3B82F6), icon: Icons.person_rounded),
  (color: Color(0xFFEF4444), icon: Icons.person_rounded),
  (color: Color(0xFFFFD700), icon: Icons.workspace_premium_rounded),
  (color: Color(0xFF60A5FA), icon: Icons.rocket_launch_rounded),
  (color: Color(0xFFF4B400), icon: Icons.emoji_events_rounded),
  (color: Color(0xFF8B5CF6), icon: Icons.auto_awesome_rounded),
  (color: Color(0xFFF59E0B), icon: Icons.bolt_rounded),
  (color: Color(0xFFEC4899), icon: Icons.favorite_rounded),
  (color: Color(0xFFFF6B35), icon: Icons.local_fire_department_rounded),
  (color: Color(0xFF22C55E), icon: Icons.star_rounded),
];

({Color color, IconData icon}) _parseAvatar(String? avatar) {
  final idx = int.tryParse(avatar ?? '0') ?? 0;
  if (idx < 0 || idx >= _avatarOptions.length) return _avatarOptions[0];
  return _avatarOptions[idx];
}

/// Full-screen settings page.
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  UserModel? _user;
  bool _editingName = false;
  bool _pickingAvatar = false;
  late TextEditingController _nameController;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final userId = context.read<int>();
    final userRepo = context.read<UserRepository>();
    final user = await userRepo.getById(userId);
    if (mounted) {
      setState(() {
        _user = user;
        _nameController.text = user?.username ?? '';
      });
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (_user == null) return;

    if (name == _user!.username) {
      setState(() { _editingName = false; _nameError = null; });
      return;
    }

    if (name.length < _nicknameMinLength || name.length > _nicknameMaxLength) {
      setState(() => _nameError = 'Emri duhet të jetë $_nicknameMinLength–$_nicknameMaxLength karaktere');
      return;
    }

    final userRepo = context.read<UserRepository>();
    final taken = await userRepo.isUsernameTaken(name, _user!.id!);
    if (taken) {
      setState(() => _nameError = 'Ky emër është i zënë');
      return;
    }

    final coinService = context.read<CoinService>();
    if (!coinService.canAfford(_nicknameCost)) {
      setState(() => _nameError = 'Duhen $_nicknameCost monedha për ndryshim');
      return;
    }

    coinService.spend(_nicknameCost);
    await userRepo.updateNickname(_user!.id!, name);
    setState(() {
      _user!.username = name;
      _editingName = false;
      _nameError = null;
    });
  }

  Future<void> _openTutorial() async {
    HapticFeedback.selectionClick();
    final prefs = context.read<SharedPreferences>();
    await prefs.setBool('fjalekryq_force_tutorial', true);
    if (!mounted) return;
    // Replace settings with the game screen so the back stack stays clean:
    // finishing the tutorial pops straight back to home.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  Future<void> _selectAvatar(int index) async {
    if (_user == null) return;
    final userRepo = context.read<UserRepository>();
    await userRepo.updateAvatar(_user!.id!, '$index');
    setState(() {
      _user!.avatar = '$index';
      _pickingAvatar = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final coins = context.watch<CoinService>().coins;
    final canAffordNickname = coins >= _nicknameCost;
    final avatar = _parseAvatar(_user?.avatar);
    final isGuest = _user?.username.startsWith('guest_') ?? true;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const AppTopBar(title: 'CILËSIMET'),

              // ── Content ──────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Profile ────────────────────────────────────
                      _buildSectionLabel('Profili'),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 52, height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: avatar.color.withValues(alpha: 0.18),
                                  border: Border.all(color: avatar.color.withValues(alpha: 0.6), width: 2),
                                ),
                                child: Icon(avatar.icon, color: avatar.color, size: 26),
                              ),
                              Positioned(
                                right: 0, bottom: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _pickingAvatar = !_pickingAvatar);
                                  },
                                  child: Container(
                                    width: 20, height: 20,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A2D5A),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                                    ),
                                    child: const Icon(Icons.camera_alt, color: Colors.white70, size: 11),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _editingName
                                ? _buildNameEditor()
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _user?.username ?? '...',
                                        style: AppFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isGuest ? 'Llogaria lokale' : 'Llogaria e regjistruar',
                                        style: AppFonts.quicksand(
                                          fontSize: 12,
                                          color: Colors.white.withValues(alpha: 0.45),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          if (!_editingName) ...[
                            const SizedBox(width: 10),
                            Opacity(
                              opacity: canAffordNickname ? 1.0 : 0.45,
                              child: GestureDetector(
                                onTap: canAffordNickname
                                    ? () {
                                        HapticFeedback.selectionClick();
                                        _nameController.text = _user?.username ?? '';
                                        setState(() {
                                          _editingName = true;
                                          _nameError = null;
                                        });
                                      }
                                    : () {
                                        HapticFeedback.selectionClick();
                                      },
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: canAffordNickname
                                            ? AppColors.purpleAccent.withValues(alpha: 0.18)
                                            : Colors.white.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(50),
                                        border: Border.all(
                                          color: canAffordNickname
                                              ? AppColors.purpleAccent.withValues(alpha: 0.5)
                                              : Colors.white.withValues(alpha: 0.12),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            canAffordNickname
                                                ? Icons.edit_rounded
                                                : Icons.lock_rounded,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Ndrysho emrin',
                                            style: AppFonts.nunito(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      top: -8,
                                      right: -6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: canAffordNickname
                                              ? AppColors.gold
                                              : const Color(0xFF6B6B6B),
                                          borderRadius: BorderRadius.circular(50),
                                          boxShadow: canAffordNickname
                                              ? [
                                                  BoxShadow(
                                                    color: AppColors.gold.withValues(alpha: 0.4),
                                                    blurRadius: 6,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.monetization_on_rounded,
                                              size: 9,
                                              color: canAffordNickname
                                                  ? const Color(0xFF7A3F00)
                                                  : Colors.white.withValues(alpha: 0.7),
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              '$_nicknameCost',
                                              style: AppFonts.nunito(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                                color: canAffordNickname
                                                    ? const Color(0xFF7A3F00)
                                                    : Colors.white.withValues(alpha: 0.85),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      if (_pickingAvatar) ...[
                        const SizedBox(height: 12),
                        _buildAvatarPicker(),
                      ],
                      if (_editingName && _nameError != null) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 66),
                          child: Text(_nameError!, style: TextStyle(fontSize: 11, color: AppColors.redAccent)),
                        ),
                      ],

                      const SizedBox(height: 20),
                      _buildDivider(),
                      const SizedBox(height: 16),

                      // ── Sound ──────────────────────────────────────
                      _buildSectionLabel('Zëri'),
                      const SizedBox(height: 10),
                      _SettingToggle(
                        icon: Icons.music_note,
                        label: 'Muzika',
                        value: settings.musicEnabled,
                        onChanged: (_) => settings.toggleMusic(),
                      ),
                      const SizedBox(height: 6),
                      _SettingToggle(
                        icon: Icons.volume_up,
                        label: 'Efektet e zërit',
                        value: settings.soundEnabled,
                        onChanged: (_) => settings.toggleSound(),
                      ),

                      const SizedBox(height: 16),
                      _buildDivider(),
                      const SizedBox(height: 16),

                      // ── Notifications ──────────────────────────────
                      _buildSectionLabel('Njoftimet'),
                      const SizedBox(height: 10),
                      _SettingToggle(
                        icon: Icons.notifications,
                        label: 'Njoftimet',
                        value: settings.notificationsEnabled,
                        onChanged: (_) => settings.toggleNotifications(),
                      ),

                      const SizedBox(height: 16),
                      _buildDivider(),
                      const SizedBox(height: 16),

                      // ── Help ───────────────────────────────────────
                      _buildSectionLabel('Ndihmë'),
                      const SizedBox(height: 10),
                      _buildLegalRow(
                        icon: Icons.school_outlined,
                        label: 'Si të luash',
                        onTap: _openTutorial,
                      ),

                      const SizedBox(height: 16),
                      _buildDivider(),
                      const SizedBox(height: 16),

                      // ── Follow us ──────────────────────────────────
                      _buildSectionLabel('Na ndiqni'),
                      const SizedBox(height: 10),
                      _buildLegalRow(
                        icon: Icons.camera_alt_outlined,
                        label: 'Instagram',
                        onTap: () {
                          HapticFeedback.selectionClick();
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildLegalRow(
                        icon: Icons.music_note_outlined,
                        label: 'TikTok',
                        onTap: () {
                          HapticFeedback.selectionClick();
                        },
                      ),

                      const SizedBox(height: 16),
                      _buildDivider(),
                      const SizedBox(height: 16),

                      // ── Legal ──────────────────────────────────────
                      _buildSectionLabel('Ligjore'),
                      const SizedBox(height: 10),
                      _buildLegalRow(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Politika e Privatësisë',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPicker() {
    final current = int.tryParse(_user?.avatar ?? '0') ?? 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: List.generate(_avatarOptions.length, (i) {
          final opt = _avatarOptions[i];
          final selected = i == current;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _selectAvatar(i);
            },
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: opt.color.withValues(alpha: selected ? 0.3 : 0.12),
                border: Border.all(
                  color: selected ? opt.color : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: Icon(opt.icon, size: 22, color: opt.color),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNameEditor() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _nameController,
            autofocus: true,
            maxLength: _nicknameMaxLength,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]'))],
            style: AppFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              counterText: '',
              hintText: '$_nicknameMinLength–$_nicknameMaxLength karaktere',
              hintStyle: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.25)),
              isDense: true,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: _nameError != null ? AppColors.redAccent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1),
                  )),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: _nameError != null ? AppColors.redAccent : AppColors.cellGreen,
                    width: 1.5,
                  )),
            ),
            onChanged: (_) { if (_nameError != null) setState(() => _nameError = null); },
            onSubmitted: (_) => _saveName(),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _saveName,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.cellGreen, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.check, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => setState(() { _editingName = false; _nameError = null; }),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.5), size: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() =>
      Container(height: 1, color: Colors.white.withValues(alpha: 0.08));

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: AppFonts.quicksand(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.4),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildLegalRow({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppFonts.quicksand(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85)),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3), size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Setting toggle row ───────────────────────────────────────────────────────

class _SettingToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingToggle({required this.icon, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: glassDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderColor: Colors.white.withValues(alpha: 0.12),
              borderRadius: 10,
            ),
            child: Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: AppFonts.quicksand(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85))),
          ),
          _CustomToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ─── Custom toggle ────────────────────────────────────────────────────────────

class _CustomToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CustomToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 50, height: 28,
        decoration: BoxDecoration(
          color: value ? const Color(0xFF22C55E) : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value ? const Color(0xFF16A34A) : Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20, height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
