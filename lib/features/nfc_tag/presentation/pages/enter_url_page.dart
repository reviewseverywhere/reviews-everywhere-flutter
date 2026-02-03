// lib/features/nfc_tag/presentation/pages/enter_url_page.dart
import 'package:flutter/material.dart';

/// Brand colours
const kBlue   = Color(0xFF0066CC);   // primary
const kOrange = Color(0xFFFF6600);   // cancel border / secondary

class EnterUrlPage extends StatefulWidget {
  final TextEditingController controller;
  const EnterUrlPage({required this.controller, super.key});

  @override
  State<EnterUrlPage> createState() => _EnterUrlPageState();
}

class _EnterUrlPageState extends State<EnterUrlPage> {
  String _scheme = 'https://';
  late final TextEditingController _pathController;
  bool get _canSetUrl => _pathController.text.trim().isNotEmpty;
  // ───────────────────────── lifecycle ─────────────────────────
  @override
  void initState() {
    super.initState();
    final text = widget.controller.text.trim();
    if (text.startsWith('http://')) {
      _scheme = 'http://';
      _pathController = TextEditingController(text: text.substring(7));
    } else if (text.startsWith('https://')) {
      _scheme = 'https://';
      _pathController = TextEditingController(text: text.substring(8));
    } else {
      _pathController = TextEditingController(text: text);
    }
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  // ───────────────────────── helpers ──────────────────────────
  void _onSetUrl() {
    widget.controller.text = '$_scheme${_pathController.text.trim()}';
    Navigator.pop(context, true);
  }

  OutlineInputBorder _outline(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c, width: w),
  );

  /// Builds one bullet row (green ✔️ or red ❌).
  Widget _bullet({required bool ok, required String text}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(ok ? Icons.check_circle : Icons.cancel,
            size: 18, color: ok ? Colors.green : Colors.red),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );

  // ───────────────────────── UI ───────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        title: const Text('Enter URL'),
        leading: BackButton(onPressed: () => Navigator.pop(context, false)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose scheme and type the rest of the address',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 16),

              // ───── URL input with scheme selector ─────
              TextField(
                controller: _pathController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'URL',
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                  hintText: 'revieweverywhere.com/',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  border: _outline(Colors.grey.shade400),
                  enabledBorder: _outline(Colors.grey.shade400),
                  focusedBorder: _outline(kBlue, 2),

                  // prefix dropdown
                  prefixIcon: Container(
                    width: 96,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.only(left: 8),      // inner padding
                    decoration: BoxDecoration(
                      border: Border(
                          right: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _scheme,
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                        iconEnabledColor: kBlue,
                        items: const [
                          DropdownMenuItem(
                              value: 'https://', child: Text('https://')),
                          DropdownMenuItem(
                              value: 'http://', child: Text('http://')),
                        ],
                        onChanged: (v) =>
                            setState(() => _scheme = v ?? _scheme),
                      ),
                    ),
                  ),
                  prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 8),
              Text(
                'Full URL: $_scheme${_pathController.text.isEmpty ? '…' : _pathController.text}',
                style:
                const TextStyle(fontSize: 12, color: Colors.grey),
              ),

              const SizedBox(height: 24),

              // ───── Professional guidelines with icons ─────
              const Text(
                'URL submission guidelines',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _bullet(
                  ok: true,
                  text:
                  'Must start with https:// (preferred) or http:// (fallback).'),
              _bullet(
                  ok: false,
                  text:
                  'Missing protocol prefix (e.g. www.example.com).'),
              _bullet(
                  ok: false,
                  text: 'Unsupported schemes: ftp://, file://, data://.'),
              _bullet(
                  ok: false,
                  text: 'javascript: pseudo-URLs or script injection.'),
              _bullet(
                  ok: false,
                  text: 'URLs longer than 2 000 characters.'),
              _bullet(
                  ok: false,
                  text: 'URLs containing HTML tags or suspicious code.'),

              const Spacer(),

              // ───── Action buttons ─────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kOrange,
                        side: const BorderSide(color: kOrange, width: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      // Enabled only when _canSetUrl is true
                      onPressed: _canSetUrl ? _onSetUrl : null,

                      // Visually dim the button when it’s disabled
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canSetUrl ? kBlue : kBlue.withOpacity(.40),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('SET URL'),
                    ),
                  ),

                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
