import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:move_wise/core/theme/app_theme.dart';
import 'package:move_wise/core/widgets/dialog_buttons.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpRow(WidgetTester tester, {required String action, double width = 280}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: ConfirmRow(
                cancelLabel: 'Keep it',
                onCancel: () {},
                action: DestructiveButton(label: action, onPressed: () {}),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('short labels sit side by side at equal widths', (tester) async {
    await pumpRow(tester, action: 'Delete', width: 320);
    final cancel = tester.getRect(find.byType(CancelButton));
    final action = tester.getRect(find.byType(DestructiveButton));
    expect(cancel.top, action.top);
    expect(cancel.width, moreOrLessEquals(action.width));
    expect(cancel.right, lessThan(action.left));
  });

  testWidgets('a label too long for half the width stacks, never cut short', (tester) async {
    await pumpRow(tester, action: 'Start new game', width: 232);
    final cancel = tester.getRect(find.byType(CancelButton));
    final action = tester.getRect(find.byType(DestructiveButton));
    expect(action.bottom, lessThan(cancel.top), reason: 'the action leads');
    expect(action.width, 232);
    final label = tester.renderObject<RenderParagraph>(find.text('Start new game'));
    expect(label.didExceedMaxLines, isFalse);
  });
}
