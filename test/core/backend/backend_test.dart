import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/core/backend/backend.dart';
import 'package:rooksight/core/llm/llm_client.dart';
import 'package:rooksight/features/settings/settings_screen.dart';

void main() {
  final status = {
    'credits': 4,
    'free': {'review': 2, 'scan': 3, 'coach': 0},
    'freePerWeek': {'review': 3, 'scan': 3, 'coach': 3},
    'price': {'review': 1, 'scan': 1, 'coach': 2},
    'paused': false,
  };

  test('reads the server\'s status', () {
    final allowance = AiAllowance.fromJson(status);
    expect(allowance.free[LlmActionKind.review], 2);
    expect(allowance.freePerWeek[LlmActionKind.coach], 3);
    expect(allowance.price[LlmActionKind.coach], 2);
    expect(allowance.credits, 4);
    expect(allowance.paused, isFalse);
  });

  test('missing counts read as zero', () {
    final allowance = AiAllowance.fromJson(const {});
    expect(allowance.free[LlmActionKind.scan], 0);
    expect(allowance.credits, 0);
  });

  test('describes what is left', () {
    expect(
      allowanceText(AiAllowance.fromJson(status)),
      'Game reviews: 2 of 3 · Board scans: 3 of 3 · Coach questions: 0 of 3. '
      'They come back each Monday. Credits: 4.',
    );
    expect(
      allowanceText(AiAllowance.fromJson({...status, 'credits': 0, 'paused': true})),
      endsWith('Monday. Free uses are paused for the rest of today.'),
    );
  });
}
