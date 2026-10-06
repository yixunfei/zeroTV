import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:zerotv_player/features/recording/domain/recording_exception.dart';
import 'package:zerotv_player/features/shared/presentation/error_localization.dart';
import 'package:zerotv_player/features/subscription/domain/sync_exception.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

void main() {
  late AppLocalizations en;
  late AppLocalizations zh;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    zh = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  test('every sync reason maps to localized text in both locales', () {
    for (final reason in SyncErrorReason.values) {
      final error = SubscriptionFetchException(reason, 'technical detail');
      final enText = localizedErrorText(en, error);
      final zhText = localizedErrorText(zh, error);
      // The technical (Chinese-era) diagnostic must not leak through.
      expect(enText, isNot(contains('technical detail')));
      expect(zhText, isNot(contains('technical detail')));
      expect(enText, isNotEmpty);
      expect(zhText, isNotEmpty);
      expect(enText, isNot(equals(zhText)));
    }
  });

  test('every recording reason maps to localized text in both locales', () {
    for (final reason in RecordingErrorReason.values) {
      final error = RecordingException(reason, 'technical detail');
      final enText = localizedErrorText(en, error);
      final zhText = localizedErrorText(zh, error);
      expect(enText, isNot(contains('technical detail')));
      expect(zhText, isNot(contains('technical detail')));
      expect(enText, isNotEmpty);
      expect(zhText, isNotEmpty);
      expect(enText, isNot(equals(zhText)));
    }
  });

  test('http status code is included in the localized message', () {
    const error = RecordingException(
      RecordingErrorReason.httpStatus,
      'HTTP 404',
      statusCode: 404,
    );
    expect(localizedErrorText(en, error), contains('404'));
    expect(localizedErrorText(zh, error), contains('404'));
  });

  test('unknown errors fall back to their toString diagnostic', () {
    final error = StateError('boom');
    expect(localizedErrorText(en, error), contains('boom'));
    expect(localizedErrorText(zh, error), contains('boom'));
  });
}
