import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/database/models/user_model.dart';
import '../../core/database/repositories/user_repository.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/settings_service.dart';
import '../../shared/constants/theme.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/offline_view.dart';
import '../../shared/widgets/shiko_button.dart';
import '../game/game_screen.dart';
import '../../core/services/consent_service.dart';
import '../legal/delete_data_screen.dart';
import '../legal/privacy_policy_screen.dart';
import '../legal/terms_of_service_screen.dart';
import 'about_screen.dart';

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
  bool _loadingRenameAds = false;
  int _renameProgress = 0; // 0 or 1 ads watched so far
  late TextEditingController _nameController;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadUser();
    _loadRenameProgress();
  }

  void _loadRenameProgress() {
    final prefs = context.read<SharedPreferences>();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = prefs.getString('fjalekryq_rename_ads_date') ?? '';
    if (savedDate == today) {
      _renameProgress = prefs.getInt('fjalekryq_rename_ads_count') ?? 0;
    }
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

    await userRepo.updateNickname(_user!.id!, name);
    // Name saved — clear the ad unlock so next rename requires 2 ads again.
    await _clearRenameProgress();
    setState(() {
      _user!.username = name;
      _renameProgress = 0;
      _editingName = false;
      _nameError = null;
    });
  }

  Future<void> _saveRenameProgress(int count) async {
    final prefs = context.read<SharedPreferences>();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString('fjalekryq_rename_ads_date', today);
    await prefs.setInt('fjalekryq_rename_ads_count', count);
  }

  Future<void> _clearRenameProgress() async {
    final prefs = context.read<SharedPreferences>();
    await prefs.remove('fjalekryq_rename_ads_date');
    await prefs.remove('fjalekryq_rename_ads_count');
  }

  Future<void> _watchAdsForRename() async {
    // Already unlocked (e.g. user cancelled after watching both ads) — reopen directly.
    if (_renameProgress >= 2) {
      _nameController.text = _user?.username ?? '';
      setState(() { _editingName = true; _nameError = null; });
      return;
    }

    final adService = context.read<AdService>();
    setState(() => _loadingRenameAds = true);

    // Ad 1: skip if already watched (app was killed after ad 1)
    if (_renameProgress < 1) {
      bool watched = false;
      await adService.showRewardedAd(
        adType: AdType.renameUser,
        onReward: () async {
          watched = true;
          _renameProgress = 1;
          await _saveRenameProgress(1);
          if (mounted) setState(() {});
        },
        onOffline: () { if (mounted) showOfflineSnack(context); },
      );
      if (!watched || !mounted) {
        setState(() => _loadingRenameAds = false);
        return;
      }
    }

    // Ad 2: shown immediately after ad 1 (no user tap needed)
    bool watched2 = false;
    await adService.showRewardedAd(
      adType: AdType.renameUser,
      onReward: () async {
        watched2 = true;
        _renameProgress = 2;
        // Save progress but don't clear — unlock persists until name is saved.
        await _saveRenameProgress(2);
        if (mounted) setState(() {});
      },
      onOffline: () { if (mounted) showOfflineSnack(context); },
    );

    if (!mounted) return;
    setState(() => _loadingRenameAds = false);

    if (watched2) {
      _nameController.text = _user?.username ?? '';
      setState(() { _editingName = true; _nameError = null; });
    }
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

  Future<void> _openPrivacyPreferences() async {
    HapticFeedback.selectionClick();
    // Re-request ATT on iOS so users can change their mind from
    // settings. On Android this is a no-op.
    try {
      await AppTrackingTransparency.requestTrackingAuthorization();
    } catch (_) {}
    // Re-show the UMP consent form (EEA/UK users). Required by
    // Google's UMP policy: users must be able to revisit choices.
    // No-op for non-EEA users.
    try {
      await ConsentService.reshow();
    } catch (_) {}
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
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
                            _loadingRenameAds
                                ? Column(
                                    children: [
                                      ShikoButton(
                                        size: ShikoSize.medium,
                                        label: 'Ndrysho',
                                        loading: true,
                                        onTap: null,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '$_renameProgress/2',
                                        style: AppFonts.nunito(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.purpleAccent,
                                        ),
                                      ),
                                    ],
                                  )
                                : _renameProgress >= 2
                                    ? GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          _watchAdsForRename();
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AppColors.purpleAccent.withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(50),
                                            border: Border.all(
                                              color: AppColors.purpleAccent.withValues(alpha: 0.5),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                                              const SizedBox(width: 5),
                                              Text(
                                                'Ndrysho',
                                                style: AppFonts.nunito(fontSize: 12, fontWeight: FontWeight.w900),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : Column(
                                        children: [
                                          ShikoButton(
                                            size: ShikoSize.medium,
                                            label: 'Ndrysho',
                                            loading: false,
                                            onTap: () {
                                              HapticFeedback.selectionClick();
                                              _watchAdsForRename();
                                            },
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '$_renameProgress/2',
                                            style: AppFonts.nunito(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.purpleAccent,
                                            ),
                                          ),
                                        ],
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

                      // ── Preferences ────────────────────────────────
                      _buildSectionLabel('Preferencat'),
                      const SizedBox(height: 10),
                      _SettingToggle(
                        icon: Icons.volume_up_rounded,
                        label: 'Zëri',
                        value: settings.audioEnabled,
                        onChanged: (_) => settings.toggleAudio(),
                      ),

                      const SizedBox(height: 16),
                      _buildDivider(),
                      const SizedBox(height: 16),

                      // ── Help & About ───────────────────────────────
                      _buildSectionLabel('Ndihmë'),
                      const SizedBox(height: 10),
                      _buildLegalRow(
                        icon: Icons.school_outlined,
                        label: 'Si të luash',
                        onTap: _openTutorial,
                      ),
                      const SizedBox(height: 8),
                      _buildLegalRow(
                        icon: Icons.info_outline_rounded,
                        label: 'Rreth lojës',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AboutScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),
                      _buildDivider(),
                      const SizedBox(height: 16),

                      // ── Privacy ────────────────────────────────────
                      // Both Apple (ATT) and Google (UMP) require a
                      // settings-accessible way to review and change
                      // privacy choices at any time.
                      _buildSectionLabel('Privatësia'),
                      const SizedBox(height: 10),
                      _buildLegalRow(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Politika e Privatësisë',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildLegalRow(
                        icon: Icons.shield_outlined,
                        label: 'Preferencat e Privatësisë',
                        onTap: _openPrivacyPreferences,
                      ),
                      const SizedBox(height: 8),
                      _buildLegalRow(
                        icon: Icons.description_outlined,
                        label: 'Kushtet e Përdorimit',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TermsOfServiceScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildLegalRow(
                        icon: Icons.delete_forever_outlined,
                        label: 'Fshi të dhënat e mia',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DeleteDataScreen(),
                            ),
                          );
                        },
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
