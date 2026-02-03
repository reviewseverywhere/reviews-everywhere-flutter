// lib/features/nfc_tag/presentation/pages/enter_url_page.dart

import 'package:flutter/material.dart';

class EnterUrlPage extends StatefulWidget {
  final TextEditingController controller;
  const EnterUrlPage({required this.controller, super.key});

  @override
  State<EnterUrlPage> createState() => _EnterUrlPageState();
}

class _EnterUrlPageState extends State<EnterUrlPage> {
  String _scheme = 'https://';
  late final TextEditingController _pathController;

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

  void _onSetUrl() {
    widget.controller.text = '$_scheme${_pathController.text.trim()}';
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8.0);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter URL'),
        leading: BackButton(onPressed: () => Navigator.pop(context, false)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'Choose scheme and type the rest of the address',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 16),

              // URL input with inline scheme dropdown
              TextField(
                controller: _pathController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'URL',
                  hintText: 'example.com/path',
                  border: OutlineInputBorder(borderRadius: borderRadius),

                  // Inline scheme selector
                  prefix: Container(
                    padding: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _scheme,
                        items: const [
                          DropdownMenuItem(
                            value: 'https://',
                            child: Text('https://'),
                          ),
                          DropdownMenuItem(
                            value: 'http://',
                            child: Text('http://'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _scheme = v);
                        },
                        iconEnabledColor: Colors.grey.shade700,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ),

                  // Remove icon constraints so prefix sits flush
                  prefixIconConstraints: const BoxConstraints(),

                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 12),
                ),
              ),
              const SizedBox(height: 8),

              // URL preview
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Full URL: $_scheme${_pathController.text.isEmpty ? '…' : _pathController.text}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),

              const Spacer(),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.colorScheme.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: borderRadius),
                      ),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _onSetUrl,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: borderRadius),
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
