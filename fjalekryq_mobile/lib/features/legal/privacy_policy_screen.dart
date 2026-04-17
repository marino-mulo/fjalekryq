import 'package:flutter/material.dart';
import '../../shared/constants/theme.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_top_bar.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const AppTopBar(title: 'POLITIKA E PRIVATËSISË'),

              // ── Content ──────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(
                        'Hyrje',
                        'Fjalekryq ("ne", "ne" ose "i yni") angazhohet të mbrojë privatësinë tuaj. Kjo politikë privatësie shpjegon se si mbledhim, përdorim dhe mbrojmë informacionin tuaj kur luani lojën tonë.',
                      ),
                      _buildSection(
                        'Informacioni që Mbledhim',
                        'Ne mbledhim informacionin minimal të nevojshëm për të ofruar shërbimin tonë:\n\n'
                        '• Të dhëna të lojës: progresi juaj, rezultatet dhe arritjet\n'
                        '• Identifikues anonimë: identifikues lokalë të gjeneruar rastësisht\n'
                        '• Të dhënat e reklamave: informacione të anonimizuara të shfaqjes së reklamave',
                      ),
                      _buildSection(
                        'Si i Përdorim të Dhënat',
                        'Informacioni i mbledhur përdoret vetëm për:\n\n'
                        '• Ruajtjen dhe sinkronizimin e progresit tuaj të lojës\n'
                        '• Shfaqjen e reklamave të personalizuara (nëse lejohet)\n'
                        '• Përmirësimin e performancës dhe stabilitetit të lojës',
                      ),
                      _buildSection(
                        'Reklamat',
                        'Loja përdor Google AdMob për të shfaqur reklama. AdMob mund të mbledhë dhe të përdorë të dhëna për të ofruar reklama të personalizuara. Mund të lexoni politikën e privatësisë së Google në: https://policies.google.com/privacy',
                      ),
                      _buildSection(
                        'Ruajtja e të Dhënave',
                        'Të gjitha të dhënat e lojës ruhen lokalisht në pajisjen tuaj. Ne nuk kemi qasje te të dhënat tuaja personale dhe nuk i ndajmë ato me palë të treta, me përjashtim të ofruesve të reklamave si Google AdMob.',
                      ),
                      _buildSection(
                        'Të Drejtat Tuaja',
                        'Keni të drejtë të:\n\n'
                        '• Aksesoni të dhënat tuaja personale\n'
                        '• Kërkoni fshirjen e të dhënave tuaja\n'
                        '• Çaktivizoni reklamat e personalizuara (nga cilësimet e pajisjes)\n'
                        '• Çinstaloni aplikacionin për të hequr të gjitha të dhënat lokale',
                      ),
                      _buildSection(
                        'Privatësia e Fëmijëve',
                        'Loja jonë nuk është e destinuar për fëmijë nën moshën 13 vjeç. Ne nuk mbledhim me vetëdije informacione personale nga fëmijët.',
                      ),
                      _buildSection(
                        'Ndryshimet e Politikës',
                        'Ne mund ta përditësojmë këtë politikë privatësie herë pas here. Ndryshimet do të publikohen në këtë faqe me datën e rishikimit të përditësuar.',
                      ),
                      _buildSection(
                        'Na Kontaktoni',
                        'Nëse keni pyetje rreth kësaj politike privatësie, na kontaktoni.\n\nData e hyrjes në fuqi: Prill 2025',
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

  Widget _buildSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: AppFonts.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.65),
            ).copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}
