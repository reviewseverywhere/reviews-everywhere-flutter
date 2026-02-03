// lib/features/nfc_tag/domain/usecases/write_url.dart

import 'package:cards/core/usecase/usecase.dart';
import 'package:cards/features/nfc_tag/domain/entities/nfc_message.dart';
import 'package:cards/features/nfc_tag/domain/repositories/nfc_repository.dart';

class WriteUrl implements UseCase<void, NfcMessage> {
  final NfcRepository repository;
  WriteUrl(this.repository);

  @override
  Future<void> call(NfcMessage msg) =>
      repository.writeUrl(msg);
}
