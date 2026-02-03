// lib/features/nfc_tag/presentation/widgets/confirm_clear_dialog.dart

import 'package:flutter/material.dart';

class ConfirmClearDialog extends StatelessWidget {
  const ConfirmClearDialog({super.key});

  @override
  Widget build(BuildContext context) {
    const iconBg = Color(0xFFFFC400);

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
                const Text('Are You Sure?',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text(
                  'This will clear all the data on the card. '
                      'Are you sure you want to clear the card?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('NO, CANCEL',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('YES, CLEAR',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Positioned(
            top: -40,
            left: 0,
            right: 0,
            child: CircleAvatar(
              radius: 32,
              backgroundColor: iconBg,
              child: const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 32),
            ),
          ),
        ],
      ),
    );
  }
}
