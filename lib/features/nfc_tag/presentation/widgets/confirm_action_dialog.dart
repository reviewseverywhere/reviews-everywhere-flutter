import 'package:flutter/material.dart';

class ConfirmActionDialog extends StatelessWidget {
  final String title;
  final String description;
  final String cancelText;
  final String confirmText;
  final IconData icon;
  final Color iconBgColor;
  final Color cancelButtonColor;
  final Color confirmButtonColor;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;

  const ConfirmActionDialog({
    super.key,
    required this.title,
    required this.description,
    this.cancelText = "Cancel",
    this.confirmText = "Confirm",
    this.icon = Icons.help_outline,
    this.iconBgColor = Colors.blue,
    this.cancelButtonColor = Colors.grey,
    this.confirmButtonColor = Colors.red,
    this.onCancel,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 24),

                // Cancel Button
                // ElevatedButton(
                //   onPressed: () {
                //     Navigator.pop(context, false);
                //     if (onCancel != null) onCancel!();
                //   },
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: cancelButtonColor,
                //     minimumSize: const Size.fromHeight(48),
                //   ),
                //   child: Text(
                //     cancelText,
                //     style: const TextStyle(
                //         color: Colors.white, fontWeight: FontWeight.bold),
                //   ),
                // ),
                const SizedBox(height: 20),

                // Confirm Button
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                    if (onConfirm != null) onConfirm!();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmButtonColor,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    confirmText,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Top Icon
          Positioned(
            top: -40,
            left: 0,
            right: 0,
            child: CircleAvatar(
              radius: 32,
              backgroundColor: iconBgColor,
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ],
      ),
    );
  }
}
