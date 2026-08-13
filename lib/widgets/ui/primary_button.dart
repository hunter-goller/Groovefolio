import 'package:flutter/material.dart';

/// Full-width primary action using the application FilledButton theme.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabledOnPressed = isLoading ? null : onPressed;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: icon == null
          ? FilledButton(
              onPressed: enabledOnPressed,
              child: _ButtonLabel(label: label, isLoading: isLoading),
            )
          : FilledButton.icon(
              onPressed: enabledOnPressed,
              icon: isLoading ? const SizedBox.shrink() : Icon(icon, size: 20),
              label: _ButtonLabel(label: label, isLoading: isLoading),
            ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.label, required this.isLoading});

  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (!isLoading) {
      return Text(label);
    }

    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 8),
        Text('Working…'),
      ],
    );
  }
}
