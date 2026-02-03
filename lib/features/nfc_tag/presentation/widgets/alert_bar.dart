import 'package:flutter/material.dart';

bool _isColorDark(Color color) => color.computeLuminance() < 0.5;

/// SnackBar helper (non-blocking notifications).
class ShowAlertBar {
  void alertDialog(
      BuildContext context,
      String title,
      Color color, {
        String? actionLabel,
        VoidCallback? onAction,
      }) {
    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.fixed,
        content: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _isColorDark(color) ? Colors.white : Colors.black,
          ),
        ),
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(
          label: actionLabel,
          onPressed: onAction,
          textColor: _isColorDark(color) ? Colors.white : Colors.black,
        )
            : null,
      ),
    );
  }
}
