// lib/features/nfc_tag/domain/repositories/nfc_repository.dart

import '../entities/nfc_message.dart';

abstract class NfcRepository {
  Future<void> writeUrl(NfcMessage message);
  Future<void> clearTag();
  Future<bool> validateUrl(String url);
}
