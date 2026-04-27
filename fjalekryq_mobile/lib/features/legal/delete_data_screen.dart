import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/config/app_config.dart';
import '../../core/database/database_helper.dart';
import '../../shared/constants/theme.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_top_bar.dart';

/// Account & data deletion screen.
///
/// **Required by Google Play** (since 2024) for any app that stores
/// user data, and by Apple for any app with user accounts. Wipes
/// every byte of user state from the device:
///
///   * SQLite database (coins, progress, settings, achievements,
///     game state, daily puzzle, daily streak, ad rewards, …)
///   * SharedPreferences (onboarding flag, migration flag, ads
///     removed flag, level completion counter, force-tutorial flag)
///
/// On the next launch the app will recreate a fresh local guest
/// account with default values — exactly as if the user had just
/// installed it.
///
/// Server-side deletion is not yet wired (the backend is still
/// placeholder). Once the API is live, add a call to
/// `RemoteAuthRepository().deleteAccount()` here before the local
/// wipe so the user's row is removed server-side too.
class DeleteDataScreen extends StatefulWidget {
  const DeleteDataScreen({super.key});

  @override
  State<DeleteDataScreen> createState() => _DeleteDataScreenState();
}

class _DeleteDataScreenState extends State<DeleteDataScreen> {
  bool _confirming = false;
  bool _deleting = false;

  Future<void> _delete() async {
    HapticFeedback.heavyImpact();
    setState(() => _deleting = true);

    final dbHelper = context.read<DatabaseHelper>();
    final prefs = context.read<SharedPreferences>();

    try {
      // Close any open handle so deleteDatabase doesn't fail on Windows.
      await dbHelper.close();
      final dbPath = p.join(await getDatabasesPath(), AppConfig.databaseName);
      await deleteDatabase(dbPath);
    } catch (e) {
      debugPrint('Data deletion: failed to drop database: $e');
    }

    try {
      await prefs.clear();
    } catch (e) {
      debugPrint('Data deletion: failed to clear prefs: $e');
    }

    // The app is now in an undefined state — every service is holding
    // stale references to the deleted DB. The cleanest path is to ask
    // the user to relaunch. SystemNavigator.pop() exits gracefully on
    // Android; on iOS Apple disallows programmatic exit, so we just
    // show a "please relaunch" message.
    if (!mounted) return;
    setState(() => _deleting = false);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2D5A),
        title: Text('Të dhënat u fshinë',
            style: AppFonts.nunito(
                fontWeight: FontWeight.w800, color: Colors.white)),
        content: Text(
          Platform.isIOS
              ? 'Të gjitha të dhënat tuaja u fshinë. Ju lutemi mbylleni dhe rihapni aplikacionin.'
              : 'Të gjitha të dhënat tuaja u fshinë. Aplikacioni do të mbyllet.',
          style: AppFonts.quicksand(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Platform.isAndroid) {
                SystemNavigator.pop();
              } else {
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
            child: Text('Në rregull',
                style: AppFonts.nunito(
                    color: AppColors.gold, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const AppTopBar(title: 'FSHI TË DHËNAT'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBanner(),
                      const SizedBox(height: 20),
                      Text('Çfarë do të fshihet',
                          style: AppFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          )),
                      const SizedBox(height: 10),
                      _bullet('Profili juaj lokal (emri, avatari)'),
                      _bullet('Të gjitha monedhat dhe progresi i niveleve'),
                      _bullet('Streak-u ditor dhe puzzle-i i ditës'),
                      _bullet('Arritjet e zhbllokuara'),
                      _bullet('Cilësimet (zëri, njoftimet)'),
                      _bullet('Historiku i shpërblimeve nga reklamat'),
                      const SizedBox(height: 20),
                      Text('Çfarë nuk mund ta fshijmë',
                          style: AppFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          )),
                      const SizedBox(height: 10),
                      _bullet('Të dhënat anonime të mbledhura nga rrjetet '
                          'reklamuese (Google AdMob). Për këto, kontrolloni '
                          'preferencat tuaja te Cilësimet → Privatësia.'),
                      const SizedBox(height: 28),
                      if (!_confirming)
                        _buildButton(
                          label: 'Vazhdo',
                          color: AppColors.redAccent,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _confirming = true);
                          },
                        )
                      else
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.redAccent
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.redAccent
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'A jeni i sigurt? Ky veprim nuk mund të zhbëhet.',
                                style: AppFonts.quicksand(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildButton(
                              label: _deleting
                                  ? 'Duke fshirë…'
                                  : 'Po, fshi gjithçka',
                              color: AppColors.redAccent,
                              onTap: _deleting ? null : _delete,
                            ),
                            const SizedBox(height: 10),
                            _buildButton(
                              label: 'Anulo',
                              color: Colors.white.withValues(alpha: 0.12),
                              onTap: _deleting
                                  ? null
                                  : () =>
                                      setState(() => _confirming = false),
                            ),
                          ],
                        ),
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

  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.redAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.redAccent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: AppColors.redAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Fshirja e të dhënave është e përhershme dhe nuk mund të zhbëhet.',
              style: AppFonts.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppFonts.quicksand(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.85),
              ).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: AppFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
