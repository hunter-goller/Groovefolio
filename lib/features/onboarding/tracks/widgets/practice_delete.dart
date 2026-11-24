import 'package:flutter/material.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';

/// Shown instead of deleting while the swipe track is being played.
Future<void> showPracticeDelete(BuildContext context, {required String title}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final colors = context.theme.colorScheme;
      final text = context.theme.textTheme;
      return AlertDialog(
        key: const Key('practice-delete'),
        icon: Icon(Icons.shield_outlined, size: 44, color: colors.primary),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF5FB49C).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                'PRACTICE MODE',
                style: TextStyle(
                  color: Color(0xFF2E7D66),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Nice move!'),
          ],
        ),
        content: Text(
          'For real, Groovefolio asks you to confirm, then removes $title and '
          'its plays. This time nothing changed.',
          textAlign: TextAlign.center,
          style: text.bodyLarge,
        ),
        actions: [
          FilledButton(
            key: const Key('practice-delete-ok'),
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      );
    },
  );
}
