import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/bank/bank_text.dart';

void main() {
  group('parseBankText', () {
    test('plain text is one segment', () {
      expect(parseBankText('Hello'), [
        const BankTextSegment('Hello', BankTextKind.plain),
      ]);
    });

    test('sub and sup become separate segments', () {
      expect(parseBankText('H<sub>2</sub>O at 10<sup>3</sup> m'), [
        const BankTextSegment('H', BankTextKind.plain),
        const BankTextSegment('2', BankTextKind.subscript),
        const BankTextSegment('O at 10', BankTextKind.plain),
        const BankTextSegment('3', BankTextKind.superscript),
        const BankTextSegment(' m', BankTextKind.plain),
      ]);
    });

    test('the "/n" tail is dropped, a "/n" inside is kept', () {
      expect(bankPlainText('An answer /n'), 'An answer');
      expect(bankPlainText('An answer/n'), 'An answer');
      expect(bankPlainText('km/n of'), 'km/n of');
    });

    test('stray tags never reach the output', () {
      expect(bankPlainText('a<sub>b'), 'ab');
      expect(bankPlainText('a</sup>b'), 'ab');
      expect(bankPlainText('<sup></sup>x'), 'x');
    });

    test('other angle brackets stay as they are', () {
      expect(bankPlainText('alpha<0 and 5 > 3'), 'alpha<0 and 5 > 3');
    });
  });

  test('spaces inside tags and double tails are handled', () {
    expect(bankPlainText('V< sub >NE< /sub > x'), 'VNE x');
    expect(bankPlainText('t = +15< sup>o< / sup >C'), 't = +15oC');
    expect(bankPlainText('a<sub >b</sub >'), 'ab');
    expect(
      parseBankText('V<sub >NE< /sub >').last.kind,
      BankTextKind.subscript,
    );
    expect(bankPlainText('will be: /n/n'), 'will be:');
    expect(bankPlainText('respectively: /n /n'), 'respectively:');
  });

  test('no source tag or "/n" tail survives in any real bank text', () {
    final leftover = RegExp(r'<\s*/?\s*su[bp]\s*>', caseSensitive: false);
    var checked = 0;
    for (final name in ['ppla', 'pplh', 'spl', 'bpl']) {
      final raw = jsonDecode(
        File('assets/data/bank_$name.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final q in raw['questions'] as List) {
        final texts = [q['q'], ...(q['a'] as List)];
        for (final t in texts) {
          for (final lang in ['pl', 'en']) {
            final text = (t as Map)[lang] as String?;
            if (text == null) continue;
            checked++;
            final shown = bankPlainText(text);
            expect(
              leftover.hasMatch(shown),
              isFalse,
              reason: '${q['id']} $lang: $shown',
            );
            expect(
              shown.endsWith('/n'),
              isFalse,
              reason: '${q['id']} $lang: $shown',
            );
          }
        }
      }
    }
    expect(checked, greaterThan(0));
  });

  group('BankText widget', () {
    Future<void> pump(WidgetTester tester, String raw) =>
        tester.pumpWidget(MaterialApp(home: Scaffold(body: BankText(raw))));

    testWidgets('plain text is a normal Text without tags or tail', (
      tester,
    ) async {
      await pump(tester, 'Answer one /n');
      expect(find.text('Answer one'), findsOneWidget);
      expect(find.textContaining('/n'), findsNothing);
    });

    testWidgets('sub/sup render as small shifted text, not as tags', (
      tester,
    ) async {
      await pump(tester, 'H<sub>2</sub>O and 10<sup>3</sup>');

      expect(find.textContaining('<sub>', findRichText: true), findsNothing);
      expect(find.textContaining('<sup>', findRichText: true), findsNothing);
      // The indices are separate small texts inside the paragraph.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      final fontSizes = {
        for (final t in tester.widgetList<Text>(find.byType(Text)))
          if (t.data == '2' || t.data == '3')
            t.data!: DefaultTextStyle.of(tester.element(find.byWidget(t))).style
                .merge(t.style)
                .fontSize,
      };
      final base = tester
          .widget<RichText>(find.byType(RichText).first)
          .text
          .style
          ?.fontSize;
      expect(fontSizes['2']!, lessThan(base ?? 14.0));
      // Accessibility label has no tags either.
      expect(tester.getSemantics(find.byType(BankText)).label, 'H2O and 103');
    });
  });
}
