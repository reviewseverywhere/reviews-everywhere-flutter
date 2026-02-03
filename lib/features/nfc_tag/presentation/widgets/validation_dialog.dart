import 'package:flutter/material.dart';
import '../../utils/url_validator.dart';

class ValidationDialog extends StatefulWidget {
  final String url;
  final Future<bool> Function(String) validator;

  const ValidationDialog({
    required this.url,
    required this.validator,
    super.key,
  });

  @override
  State<ValidationDialog> createState() => _ValidationDialogState();
}

class _ValidationDialogState extends State<ValidationDialog> {
  bool? _ok; // null = still checking

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  Future<void> _runCheck() async {
    // 1) Local format checks
    if (!UrlValidator.isValidFormat(widget.url)) {
      setState(() => _ok = false);
      return;
    }
    // 2) Remote reachability check
    final res = await widget.validator(widget.url);
    setState(() => _ok = res);
  }

  @override
  Widget build(BuildContext context) {
    const iconBg = Color(0xFF50CFFF);

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
                const Text(
                  'Validating URL',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // ─── Status Display ─────────────────────────────────
                if (_ok == null) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  const Text(
                    'Checking the URL you entered is valid.\nPlease wait...',
                    textAlign: TextAlign.center,
                  ),
                ] else if (_ok == true) ...[
                  const Icon(Icons.check_circle, color: Colors.green, size: 48),
                  const SizedBox(height: 8),
                  const Text(
                    'URL looks good!',
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 8),
                  const Text(
                    'Invalid URL format.\n'
                        'Ensure it starts with http:// or https://\n'
                        'and contains no HTML or unsupported schemes.',
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 24),

                // ─── Action Buttons ─────────────────────────────────
                if (_ok == true) ...[
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade200,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text(
                      'WRITE ANYWAY',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Top Icon ────────────────────────────────────────
          Positioned(
            top: -40,
            left: 0,
            right: 0,
            child: CircleAvatar(
              radius: 32,
              backgroundColor: iconBg,
              child: const Icon(Icons.link, color: Colors.white, size: 32),
            ),
          ),
        ],
      ),
    );
  }
}
