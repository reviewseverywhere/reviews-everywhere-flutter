// lib/features/nfc_tag/data/datasources/nfc_remote_data_source.dart
// ------------------------------------------------------------------
// Low-level NFC access + URL reachability.
//
// • writeTag  – writes a URI record, waits until the tag is touched.
// • clearTag  – blanks the tag safely (formats instead of empty-write).
// • checkUrl  – HEAD/GET reachability check.
//
// ------------------------------------------------------------------

// ignore_for_file: invalid_return_type_for_catch_error

import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

abstract class NfcRemoteDataSource {
  Future<void> writeTag(String rawUrl);
  Future<void> clearTag();
  Future<bool> checkUrl(String url);
}

class NfcRemoteDataSourceImpl implements NfcRemoteDataSource {
// ───────────────────────── WRITE ─────────────────────────
  @override
  Future<void> writeTag(String rawUrl) async {
    final completer = Completer<void>();

    final url =
        rawUrl.startsWith(RegExp(r'https?://')) ? rawUrl : 'https://$rawUrl';

    await NfcManager.instance.startSession(
      alertMessage: 'Hold your device close to the NFC tag to write URL',
      onDiscovered: (tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef != null && ndef.isWritable) {
            await ndef.write(NdefMessage([
              NdefRecord.createUri(Uri.parse(url)),
            ]));
          } else {
            final fmt = NdefFormatable.from(tag);
            if (fmt == null)
              throw 'Tag is not NDEF-formatted and not formatable';
            await fmt.format(NdefMessage([
              NdefRecord.createUri(Uri.parse(url)),
            ]));
          }

          await NfcManager.instance.stopSession();
          completer.complete();
        } catch (e) {
          await NfcManager.instance.stopSession(errorMessage: e.toString());
          completer.completeError(e);
        }
      },
    );

    return completer.future;
  }

// ───────────────────────── CLEAR ────────────────────────
  @override
  Future<void> clearTag() async {
    final completer = Completer<void>();

    await NfcManager.instance.startSession(
      alertMessage: 'Hold your device close to the NFC tag to clear it',
      onDiscovered: (tag) async {
        try {
          final ndef = Ndef.from(tag);

          // 1) Already blank? → nothing to do
          if (ndef != null) {
            final msg = await ndef.read().catchError((_) => ndef.cachedMessage);
            if ((msg?.records ?? []).isEmpty) {
              await NfcManager.instance.stopSession();
              completer.complete();
              return;
            }
          }

          // 2) Clear logic
          if (NdefFormatable.from(tag) != null) {
            // Format to an empty NDEF container
            await NdefFormatable.from(tag)!.format(
              NdefMessage([
                NdefRecord.createText(''), // minimal placeholder, Android-safe
              ]),
            );
          } else if (ndef != null && ndef.isWritable) {
            // Overwrite with a placeholder record to avoid empty write crash
            await ndef.write(
              NdefMessage([
                NdefRecord.createText(''), // minimal placeholder
              ]),
            );
          } else {
            await _manualClearType2(tag); // Fallback for Type-2 tags
          }

          await NfcManager.instance.stopSession();
          completer.complete();
        } catch (e) {
          await NfcManager.instance.stopSession(errorMessage: e.toString());
          completer.completeError(e);
        }
      },
    );

    return completer.future;
  }

// ───────────────────────── URL CHECK ─────────────────────
  @override
  Future<bool> checkUrl(String url) async {
    final testUrl = url.startsWith(RegExp(r'https?://')) ? url : 'https://$url';
    try {
      final uri = Uri.parse(testUrl);
      final head = await http.head(uri).timeout(
            const Duration(seconds: 5),
            onTimeout: () => http.Response('', 408),
          );
      if (head.statusCode >= 200 && head.statusCode < 400) return true;

      final get = await http.get(uri).timeout(const Duration(seconds: 7));
      return get.statusCode >= 200 && get.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

// ───────── helper for MifareUltralight (Type-2) ──────────
  Future<void> _manualClearType2(NfcTag tag) async {
    final ul = MifareUltralight.from(tag);
    if (ul == null) throw 'Tag is not a MifareUltralight / Type-2 tag';

    for (var page = 4; page <= 7; page++) {
      final cmd = Uint8List.fromList([0xA2, page, 0, 0, 0, 0]);
      final resp = await ul.transceive(data: cmd);
      if (resp.length != 1 || resp[0] != 0x0A) {
        throw 'Page $page clear failed (resp = ${resp.toList()})';
      }
    }
  }
}
