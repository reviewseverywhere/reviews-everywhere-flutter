// lib/features/nfc_tag/data/repositories/nfc_repository_impl.dart

import 'package:cards/features/nfc_tag/data/datasources/nfc_remote_data_source.dart';
import 'package:cards/features/nfc_tag/domain/entities/nfc_message.dart';
import 'package:cards/features/nfc_tag/domain/repositories/nfc_repository.dart';

class NfcRepositoryImpl implements NfcRepository {
  final NfcRemoteDataSource remote;
  NfcRepositoryImpl(this.remote);

  @override
  Future<void> writeUrl(NfcMessage message) =>
      remote.writeTag(message.uri);

  @override
  Future<void> clearTag() =>
      remote.clearTag();

  @override
  Future<bool> validateUrl(String url) =>
      remote.checkUrl(url);
}
