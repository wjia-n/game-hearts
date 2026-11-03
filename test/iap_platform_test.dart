import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearts/services/iap_service.dart';

void main() {
  test('iOS maps to the single Gold Star product', () {
    expect(HeartsStore.productIdsFor(TargetPlatform.iOS), {'heartsstar'});
    expect(HeartsStore.starId, 'heartsstar');
  });
  test('Android maps to coffee + chocolate', () {
    expect(HeartsStore.productIdsFor(TargetPlatform.android),
        {'heartscoffee', 'heartschocolate'});
  });
  test('iOS and Android product sets do not overlap', () {
    expect(HeartsStore.productIdsFor(TargetPlatform.iOS)
        .intersection(HeartsStore.productIdsFor(TargetPlatform.android)), isEmpty);
  });
}
