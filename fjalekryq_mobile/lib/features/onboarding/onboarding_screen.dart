import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/coin_service.dart';
import '../../shared/constants/theme.dart';
import '../../shared/widgets/background_tiles.dart';
import '../home/home_screen.dart';

const _onboardingDoneKey = 'fjalekryq_onboarding_done';
const _accountTypeKey = 'fjalekryq_account_type'; // 'google' | 'guest'
const _guestUsernameKey = 'fjalekryq_guest_username';

/// Shown once on first launch. Player chooses Google (+100 coins) or Guest.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  bool _loadingGoogle = false;
  bool _loadingGuest = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fadeCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  static String _generateGuestName() {
    final rng = Random();
    const adjectives = [
      'Trim', 'Guximtar', 'Mençur', 'Shpejtë', 'Zgjuar',
      'Fortë', 'Shkel', 'Ditur', 'Lirë', 'Fisnik',
    ];
    const nouns = [
      'Luajtas', 'Kampion', 'Yll', 'Hero', 'Zog',
      'Ujk', 'Shqiponjë', 'Luan', 'Djalë', 'Vajzë',
    ];
    final adj = adjectives[rng.nextInt(adjectives.length)];
    final noun = nouns[rng.nextInt(nouns.length)];
    final num = 100 + rng.nextInt(900);
    return '$adj$noun$num';
  }

  Future<void> _continueWithGoogle() async {
    HapticFeedback.mediumImpact();
    setState(() => _loadingGoogle = true);

    // Simulate Google auth (placeholder — replace with real firebase_auth)
    await Future.delayed(const Duration(milliseconds: 1400));

    if (!mounted) return;
    final prefs = context.read<SharedPreferences>();
    final coins = context.read<CoinService>();

    await prefs.setString(_accountTypeKey, 'google');
    await prefs.setBool(_onboardingDoneKey, true);
    // Award 100 coins for account creation
    coins.add(100);

    if (!mounted) return;
    setState(() => _loadingGoogle = false);
    _navigateHome();
  }

  Future<void> _continueAsGuest() async {
    HapticFeedback.lightImpact();
    setState(() => _loadingGuest = true);

    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    final prefs = context.read<SharedPreferences>();

    final guestName = _generateGuestName();
    await prefs.setString(_accountTypeKey, 'guest');
    await prefs.setString(_guestUsernameKey, guestName);
    await prefs.setBool(_onboardingDoneKey, true);

    if (!mounted) return;
    setState(() => _loadingGuest = false);
    _navigateHome();
  }

  void _navigateHome() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0C1F4A), Color(0xFF123B86), Color(0xFF07152F)],
            stops: [0.0, 0.48, 1.0],
          ),
        ),
        child: Stack(
          children: [
            const BackgroundTiles(animate: true),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),

                        // Logo tile
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: AppColors.purpleAccent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: AppColors.purpleAccent.withValues(alpha: 0.45),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.purpleAccent.withValues(alpha: 0.3),
                                blurRadius: 32,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.grid_view_rounded,
                            color: Color(0xFFD8B4FE),
                            size: 44,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Title
                        Text(
                          'FJALËKRYQ',
                          style: AppFonts.nunito(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Zgjidh fjalëkryqin me lëvizje strategjike',
                          textAlign: TextAlign.center,
                          style: AppFonts.quicksand(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),

                        const Spacer(flex: 2),

                        // +100 coins badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CoinIcon(size: 14),
                              const SizedBox(width: 6),
                              Text(
                                '+100 monedha për regjistrim',
                                style: AppFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.gold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Continue with Google button
                        _buildGoogleButton(),
                        const SizedBox(height: 12),

                        // Continue as Guest button
                        _buildGuestButton(),

                        const SizedBox(height: 12),

                        // Privacy note
                        Text(
                          'Duke vazhduar, pranoni Kushtet e Shërbimit',
                          textAlign: TextAlign.center,
                          style: AppFonts.quicksand(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        const Spacer(flex: 1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return GestureDetector(
      onTap: (_loadingGoogle || _loadingGuest) ? null : _continueWithGoogle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _loadingGoogle
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF4285F4),
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google "G" icon
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: const Text(
                      'G',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4285F4),
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Vazhdo me Google',
                    style: AppFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildGuestButton() {
    return GestureDetector(
      onTap: (_loadingGoogle || _loadingGuest) ? null : _continueAsGuest,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: _loadingGuest
            ? Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_outline,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Vazhdo si Mysafir',
                    style: AppFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Prompt shown after 5+ levels as guest encouraging account creation.
class SaveProgressPrompt extends StatelessWidget {
  final VoidCallback onSaveWithGoogle;
  final VoidCallback onDismiss;

  const SaveProgressPrompt({
    super.key,
    required this.onSaveWithGoogle,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A2D5A), Color(0xFF0F2251)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.purpleAccent.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.purpleAccent.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.cloud_upload_outlined,
                color: Color(0xFFD8B4FE),
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Ruaj progresin tënd!',
              style: AppFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Krijo llogari me Google dhe mos humb nivelet e luajtura. Merr edhe +100 monedha falas!',
              textAlign: TextAlign.center,
              style: AppFonts.quicksand(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 18),
            // Coins bonus row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CoinIcon(size: 16),
                const SizedBox(width: 6),
                Text(
                  '+100 monedha bonus',
                  style: AppFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Save with Google button
            GestureDetector(
              onTap: onSaveWithGoogle,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.93),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'G',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4285F4),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Ruaj me Google',
                      style: AppFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Dismiss
            GestureDetector(
              onTap: onDismiss,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Tani jo, faleminderit',
                  style: AppFonts.quicksand(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
