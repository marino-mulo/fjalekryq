import 'package:flutter/material.dart';
import '../../../shared/constants/theme.dart';

class SaveProgressPromptModal extends StatefulWidget {
  final Future<void> Function() onSaveWithGoogle;
  final VoidCallback onDismiss;

  const SaveProgressPromptModal({
    super.key,
    required this.onSaveWithGoogle,
    required this.onDismiss,
  });

  @override
  State<SaveProgressPromptModal> createState() => _SaveProgressPromptModalState();
}

class _SaveProgressPromptModalState extends State<SaveProgressPromptModal> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A2D5A), Color(0xFF0F2251)],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.purpleAccent.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.purpleAccent.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.cloud_upload_outlined,
                  color: Color(0xFFD8B4FE), size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              'Ruaj progresin tënd!',
              style: AppFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Ke luajtur 5+ nivele si mysafir. Krijo llogari me Google dhe mos humb progresin.',
              textAlign: TextAlign.center,
              style: AppFonts.quicksand(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: _loading
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      await widget.onSaveWithGoogle();
                      if (mounted) setState(() => _loading = false);
                    },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.93),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF4285F4),
                          ),
                        ),
                      )
                    : Row(
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
            GestureDetector(
              onTap: widget.onDismiss,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Tani jo, faleminderit',
                  style: AppFonts.quicksand(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.35),
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
