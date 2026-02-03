import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ActionRequiredDialog {
  const ActionRequiredDialog._();

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    required Color accentColor,
    required Uri websiteUri,
    required String websiteDisplay,
    bool barrierDismissible = true,
  }) async {
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(fontSize: 14, height: 1.35),
              ),
              const SizedBox(height: 14),

              // Website card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black12),
                  color: Colors.black.withOpacity(0.03),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        websiteDisplay,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: "Copy",
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: websiteDisplay));
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text("Link copied")),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Close"),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final ok = await launchUrl(
                    websiteUri,
                    mode: LaunchMode.externalApplication,
                  );
                  if (!ok && ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text("Unable to open website")),
                    );
                  }
                } catch (_) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text("Unable to open website")),
                    );
                  }
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text("Open Website"),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      },
    );
  }

  static Future<void> purchaseRequired({
    required BuildContext context,
    required Uri websiteUri,
    required String websiteDisplay,
  }) {
    return show(
      context: context,
      title: "Purchase required",
      message: "No active wristband plan found. Please purchase from $websiteDisplay to continue.",
      accentColor: Colors.red,
      websiteUri: websiteUri,
      websiteDisplay: websiteDisplay,
    );
  }

  static Future<void> accountNotActive({
    required BuildContext context,
    required Uri websiteUri,
    required String websiteDisplay,
  }) {
    return show(
      context: context,
      title: "Account not active",
      message:
      "Your account is not active yet. If you purchased recently, please wait a few minutes for the order to sync. "
          "Otherwise, purchase from $websiteDisplay.",
      accentColor: Colors.orange,
      websiteUri: websiteUri,
      websiteDisplay: websiteDisplay,
    );
  }
}
