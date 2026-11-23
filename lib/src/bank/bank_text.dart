import 'package:flutter/material.dart';

/// Kind of a piece of bank text.
enum BankTextKind { plain, subscript, superscript }

class BankTextSegment {
  const BankTextSegment(this.text, this.kind);

  final String text;
  final BankTextKind kind;

  @override
  bool operator ==(Object other) =>
      other is BankTextSegment && other.text == text && other.kind == kind;

  @override
  int get hashCode => Object.hash(text, kind);

  @override
  String toString() => 'BankTextSegment($kind, "$text")';
}

final RegExp _tail = RegExp(r'\s*/n\s*$');
final RegExp _markup = RegExp(
  r'<(sub|sup)>(.*?)</\1>',
  caseSensitive: false,
  dotAll: true,
);
final RegExp _strayTag = RegExp(r'</?su[bp]>', caseSensitive: false);

/// Splits a text of the bank into plain, subscript and superscript pieces and
/// drops the "/n" tail that some English texts of the source carry. The data
/// of the bank itself is never changed; this is applied only for display.
List<BankTextSegment> parseBankText(String raw) {
  final text = raw.replaceFirst(_tail, '').trim();
  final segments = <BankTextSegment>[];
  void addPlain(String s) {
    final cleaned = s.replaceAll(_strayTag, '');
    if (cleaned.isNotEmpty) {
      segments.add(BankTextSegment(cleaned, BankTextKind.plain));
    }
  }

  var last = 0;
  for (final m in _markup.allMatches(text)) {
    addPlain(text.substring(last, m.start));
    final inner = m.group(2)!.replaceAll(_strayTag, '');
    if (inner.isNotEmpty) {
      segments.add(
        BankTextSegment(
          inner,
          m.group(1)!.toLowerCase() == 'sub'
              ? BankTextKind.subscript
              : BankTextKind.superscript,
        ),
      );
    }
    last = m.end;
  }
  addPlain(text.substring(last));
  return segments;
}

/// The text as one plain string (tags and the "/n" tail removed), for
/// accessibility labels and comparisons.
String bankPlainText(String raw) =>
    parseBankText(raw).map((s) => s.text).join();

/// Renders a bank text: `<sub>` / `<sup>` as lowered / raised small text,
/// the "/n" tail is not shown.
class BankText extends StatelessWidget {
  const BankText(this.raw, {super.key, this.style, this.textAlign});

  final String raw;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final segments = parseBankText(raw);
    if (segments.every((s) => s.kind == BankTextKind.plain)) {
      return Text(
        segments.map((s) => s.text).join(),
        style: style,
        textAlign: textAlign,
      );
    }
    final base = DefaultTextStyle.of(context).style.merge(style);
    final size = base.fontSize ?? 14;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final s in segments)
            if (s.kind == BankTextKind.plain)
              TextSpan(text: s.text)
            else
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    s.kind == BankTextKind.subscript
                        ? size * 0.25
                        : -size * 0.4,
                  ),
                  child: Text(
                    s.text,
                    style: base.copyWith(fontSize: size * 0.7),
                  ),
                ),
              ),
        ],
      ),
      textAlign: textAlign,
      semanticsLabel: segments.map((s) => s.text).join(),
    );
  }
}
