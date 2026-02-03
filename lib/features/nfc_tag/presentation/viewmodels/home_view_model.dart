// lib/features/nfc_tag/presentation/viewmodels/home_view_model.dart

import 'package:flutter/material.dart';
import 'package:cards/core/usecase/usecase.dart';
import 'package:cards/features/nfc_tag/domain/entities/nfc_message.dart';
import 'package:cards/features/nfc_tag/domain/usecases/write_url.dart';
import 'package:cards/features/nfc_tag/domain/usecases/clear_tag.dart';
import 'package:cards/features/nfc_tag/domain/usecases/validate_url.dart';

enum ViewState { idle, busy, success, error }

enum NfcAction { none, write, clear } // Track last action type

class HomeViewModel extends ChangeNotifier {
  final WriteUrl writeUrl;
  final ClearTag clearTag;
  final ValidateUrl validateUrl;

  HomeViewModel({
    required this.writeUrl,
    required this.clearTag,
    required this.validateUrl,
  });

  ViewState state = ViewState.idle;
  NfcAction lastAction = NfcAction.none;
  String? errorMessage;

  Future<void> onWrite(String url) async {
    lastAction = NfcAction.write;
    errorMessage = null; // reset old errors
    state = ViewState.busy;
    notifyListeners();

    try {
      await writeUrl(NfcMessage(url));
      state = ViewState.success;
    } catch (e) {
      errorMessage = e.toString();
      state = ViewState.error;
    }
    notifyListeners();
  }

  Future<void> onClear() async {
    lastAction = NfcAction.clear;
    errorMessage = null; // reset old errors
    state = ViewState.busy;
    notifyListeners();

    try {
      await clearTag(NoParams());
      state = ViewState.success;
    } catch (e) {
      errorMessage = e.toString();
      state = ViewState.error;
    }
    notifyListeners();
  }

  Future<bool> checkUrl(String url) => validateUrl(url);
}
