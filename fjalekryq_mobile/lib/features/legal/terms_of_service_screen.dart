import 'package:flutter/material.dart';
import '../../shared/constants/theme.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_top_bar.dart';

/// Terms of Service shown from Settings → Privacy section.
///
/// Plain-text Albanian content covering use of the service, user
/// conduct, virtual currency (coins are not real money and have no
/// cash value), ads, IAP, account termination, and governing law.
/// Pair this with a privacy policy hosted at a public URL when
/// submitting to Play / App Store — both stores require the URL
/// outside the app, not just an in-app screen.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const AppTopBar(title: 'KUSHTET E PËRDORIMIT'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _section(
                        '1. Pranimi i Kushteve',
                        'Duke shkarkuar, instaluar ose duke përdorur Fjalëkryq ("Loja"), ju '
                            'pranoni të jeni të lidhur nga këto Kushte të Përdorimit. Nëse '
                            'nuk pajtoheni, ju lutemi mos e përdorni lojën.',
                      ),
                      _section(
                        '2. Përshkrimi i Shërbimit',
                        'Fjalëkryq është një lojë puzzle me fjalë në gjuhën shqipe. Loja '
                            'mund të luhet jashtë linje pas instalimit fillestar dhe nuk '
                            'kërkon krijim llogarie.',
                      ),
                      _section(
                        '3. Sjellja e Përdoruesit',
                        'Ju pajtoheni të mos: (a) anashkaloni, çaktivizoni ose ndërhyni në '
                            'çdo masë sigurie të lojës; (b) përdorni mjete të automatizuara '
                            'për të luajtur; (c) shisni ose tregtoni monedha në botën reale; '
                            '(d) krijoni emra përdoruesi fyes ose që cenojnë të drejtat e të '
                            'tjerëve.',
                      ),
                      _section(
                        '4. Monedhat Virtuale',
                        'Monedhat brenda lojës nuk kanë vlerë monetare në botën reale, nuk '
                            'janë të shkëmbyeshme për para dhe nuk mund të transferohen jashtë '
                            'lojës. Ato fitohen duke luajtur, duke shikuar reklama ose mund '
                            'të blihen përmes blerjeve brenda aplikacionit aty ku ofrohen.',
                      ),
                      _section(
                        '5. Reklamat',
                        'Loja shfaq reklama nga Google AdMob. Disa reklama janë të '
                            'shpërblyera (jepni leje për t\'i parë në këmbim të monedhave). '
                            'Shih Politikën tonë të Privatësisë për të dhënat që përdoren nga '
                            'rrjetet reklamuese.',
                      ),
                      _section(
                        '6. Blerjet brenda Aplikacionit',
                        'Aty ku ofrohen, blerjet brenda aplikacionit (p.sh. "Hiq Reklamat") '
                            'përpunohen nga Apple App Store ose Google Play. Të gjitha '
                            'blerjet janë përfundimtare dhe nuk rimbursohen, përveç rastit kur '
                            'kërkohet nga ligji në fuqi ose nga politikat e dyqanit.',
                      ),
                      _section(
                        '7. Përfundimi',
                        'Ne mund të pezullojmë ose ndërpresim aksesin tuaj në lojë në çdo '
                            'kohë për shkelje të këtyre kushteve. Ju mund të çinstaloni lojën '
                            'dhe të fshini të dhënat tuaja lokale në çdo moment nga menyja '
                            'Cilësimet → Privatësia → Fshi të dhënat e mia.',
                      ),
                      _section(
                        '8. Mohimi i Garancisë',
                        'Loja ofrohet "ashtu siç është", pa asnjë garanci. Ne nuk garantojmë '
                            'që loja do të jetë gjithmonë e disponueshme, pa gabime ose e sigurt.',
                      ),
                      _section(
                        '9. Kufizimi i Përgjegjësisë',
                        'Në masën maksimale të lejuar nga ligji, LojraLogjike nuk mban '
                            'përgjegjësi për ndonjë dëm të tërthortë, të rastësishëm ose pasues '
                            'që rrjedh nga përdorimi i lojës.',
                      ),
                      _section(
                        '10. Ndryshimet',
                        'Ne mund të përditësojmë këto kushte herë pas here. Ndryshimet '
                            'materiale do të njoftohen brenda lojës. Vazhdimi i përdorimit '
                            'pas ndryshimit përbën pranim të kushteve të reja.',
                      ),
                      _section(
                        '11. Kontakti',
                        'Për pyetje ose ankesa në lidhje me këto kushte, na kontaktoni në '
                            'support@lojralogjike.com.',
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Përditësuar së fundmi: 2026',
                        style: AppFonts.quicksand(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.45),
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
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppFonts.quicksand(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
            ).copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
