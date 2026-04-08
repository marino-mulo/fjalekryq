import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/database/repositories/user_repository.dart';
import '../../core/database/repositories/progress_repository.dart';
import '../../core/database/models/user_model.dart';
import '../../shared/constants/theme.dart';

/// Predefined avatar options — color + icon combos the user can pick.
const _avatarOptions = [
  (color: Color(0xFF22C55E), icon: Icons.person),
  (color: Color(0xFF3B82F6), icon: Icons.person),
  (color: Color(0xFFF4B400), icon: Icons.person),
  (color: Color(0xFFE879F9), icon: Icons.person),
  (color: Color(0xFFFCA5A5), icon: Icons.person),
  (color: Color(0xFF06B6D4), icon: Icons.person),
  (color: Color(0xFFA78BFA), icon: Icons.person),
  (color: Color(0xFFFF6B6B), icon: Icons.person),
  (color: Color(0xFF10B981), icon: Icons.emoji_nature),
  (color: Color(0xFF8B5CF6), icon: Icons.auto_awesome),
  (color: Color(0xFFF59E0B), icon: Icons.bolt),
  (color: Color(0xFFEC4899), icon: Icons.favorite),
];

/// Parse avatar string "index" to option, default to index 0.
({Color color, IconData icon}) _parseAvatar(String? avatar) {
  if (avatar == null) return _avatarOptions[0];
  final idx = int.tryParse(avatar) ?? 0;
  if (idx < 0 || idx >= _avatarOptions.length) return _avatarOptions[0];
  return _avatarOptions[idx];
}

/// Profile & stats bottom sheet.
class ProfileSheet extends StatefulWidget {
  const ProfileSheet({super.key});

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  UserModel? _user;
  int _totalStars = 0;
  int _levelsCompleted = 0;
  bool _editingName = false;
  late TextEditingController _nameController;
  bool _pickingAvatar = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final userId = context.read<int>();
    final userRepo = context.read<UserRepository>();
    final progressRepo = context.read<ProgressRepository>();

    final user = await userRepo.getById(userId);
    final stars = await progressRepo.getTotalStars(userId);
    final levels = await progressRepo.getCompletedCount(userId);

    if (mounted) {
      setState(() {
        _user = user;
        _totalStars = stars;
        _levelsCompleted = levels;
        _nameController.text = user?.username ?? '';
      });
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _user == null) return;
    final userRepo = context.read<UserRepository>();
    await userRepo.updateNickname(_user!.id!, name);
    setState(() {
      _user!.username = name;
      _editingName = false;
    });
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
    final avatar = _parseAvatar(_user?.avatar);
    final isGuest = _user?.username.startsWith('guest_') ?? true;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF142452), Color(0xFF0D1B40)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.person_rounded, color: Colors.white60, size: 22),
                const SizedBox(width: 10),
                const Text(
                  'Profili',
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close, color: Colors.white38, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Avatar + name
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _pickingAvatar = !_pickingAvatar);
            },
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: avatar.color.withValues(alpha: 0.2),
                border: Border.all(color: avatar.color, width: 3),
              ),
              child: Icon(avatar.icon, size: 38, color: avatar.color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ndrysho avatarin',
            style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 12),

          // Avatar picker (expandable)
          if (_pickingAvatar) ...[
            _buildAvatarPicker(),
            const SizedBox(height: 12),
          ],

          // Nickname
          if (_editingName)
            _buildNameEditor()
          else
            _buildNameDisplay(isGuest),

          const SizedBox(height: 24),

          // Stats cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: _buildStatCard(
                  icon: Icons.flag_rounded,
                  iconColor: AppColors.cellGreen,
                  label: 'Nivele',
                  value: '$_levelsCompleted',
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard(
                  icon: Icons.star_rounded,
                  iconColor: AppColors.gold,
                  label: 'Yje',
                  value: '$_totalStars',
                )),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Guest info banner
          if (isGuest)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.gold, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Je duke luajtur si mysafir. Progresi ruhet vetëm në këtë pajisje.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.gold.withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          SizedBox(height: bottomPad + 20),
        ],
      ),
    );
  }

  Widget _buildAvatarPicker() {
    final current = int.tryParse(_user?.avatar ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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

  Widget _buildNameDisplay(bool isGuest) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _editingName = true);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _user?.username ?? '...',
            style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildNameEditor() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _nameController,
              autofocus: true,
              maxLength: 20,
              style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Emri yt...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.cellGreen, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _saveName(),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _saveName,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.cellGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
