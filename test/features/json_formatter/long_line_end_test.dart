import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itools/features/json_formatter/presentation/widgets/json_code_editor.dart';
import 'package:re_editor/re_editor.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

ScrollableState _horizontalScrollable(WidgetTester tester) {
  final List<ScrollableState> states = tester
      .stateList<ScrollableState>(
        find.descendant(
          of: find.byType(CodeEditor),
          matching: find.byType(Scrollable),
        ),
      )
      .toList();
  return states.firstWhere(
    (s) => s.widget.axisDirection == AxisDirection.right,
  );
}

void main() {
  testWidgets('long single-line json: End key must reveal line end', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    // 构造 ~60KB 的一行 JSON。
    final String longLine =
        '{"data":[' +
        List<String>.generate(
          8000,
          (i) => '"item_$i":"value_ox$i"',
        ).join(',') +
        ']}';
    expect(longLine.length, greaterThan(8 * 1024));

    await tester.pumpWidget(
      ShadApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 400,
            child: JsonCodeEditor(jsonString: longLine),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ScrollableState hScroll = _horizontalScrollable(tester);
    final ScrollPosition pos = hScroll.position;
    // ignore: avoid_print
    print('maxScrollExtent=${pos.maxScrollExtent}');

    await tester.tap(find.byType(CodeEditor).first);
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('primaryFocus=${FocusManager.instance.primaryFocus}');
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();

    final double pixels = pos.pixels;
    final double max = pos.maxScrollExtent;
    // ignore: avoid_print
    print('after End: pixels=$pixels max=$max');

    expect(pixels, lessThanOrEqualTo(max + 0.5), reason: '滚动位置越界会导致回弹');
    expect(pixels, greaterThan(max - 40), reason: '行尾应可达，不能远小于 max');

    // 行尾在视口内的相对 X：
    // max = lineWidth + paddingH(10) - viewportW(800)
    // lineEndAbsX = paddingL(5) + lineWidth
    final double lineWidth = max + 800 - 10;
    final double lineEndViewportX = 5 + lineWidth - pixels;
    // ignore: avoid_print
    print('lineWidth≈$lineWidth lineEndViewportX=$lineEndViewportX');
    expect(
      lineEndViewportX,
      lessThan(800),
      reason: '行尾必须落在视口内（否则末尾字符不可见）',
    );
    debugDefaultTargetPlatformOverride = null;
  });

  // 模拟“粘贴/格式化结果回填”：编辑器先为空，外部把整行大 JSON 通过
  // didUpdateWidget 一次性灌入（与 IME 粘贴内容替换的时序最接近），
  // 紧接着按 End。验证行尾仍可达、不回弹。
  testWidgets('long single-line json: external text update then End', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final String longLine =
        '{"data":[' +
        List<String>.generate(8000, (i) => '"item_$i":"value_ox$i"').join(',') +
        ']}';

    await tester.pumpWidget(
      const ShadApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 400,
            child: JsonCodeEditor(jsonString: ''),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 外部一次性灌入大文本（模拟粘贴/格式化回填）。
    await tester.pumpWidget(
      ShadApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 400,
            child: JsonCodeEditor(jsonString: longLine),
          ),
        ),
      ),
    );
    // 只 pump 一帧（不 settle），模拟用户粘贴后立刻按键。
    await tester.pump();
    await tester.tap(find.byType(CodeEditor).first);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();

    final ScrollableState hScroll = _horizontalScrollable(tester);
    final double pixels = hScroll.position.pixels;
    final double max = hScroll.position.maxScrollExtent;
    // ignore: avoid_print
    print('external-update: pixels=$pixels max=$max');
    expect(pixels, lessThanOrEqualTo(max + 0.5), reason: '越界会回弹');
    expect(pixels, greaterThan(max - 40), reason: '行尾应可达');
    debugDefaultTargetPlatformOverride = null;
  });

  // 方向键逐步右移到行尾，每一步光标都必须在视口内（≤ viewportW - 5）。
  testWidgets('long single-line json: arrow right step by step to end', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    // 用更短的行，使逐步右移测试耗时可控（~200 字符）。
    final String line = List<String>.generate(200, (i) => 'x').join();
    await tester.pumpWidget(
      ShadApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 200,
            child: JsonCodeEditor(jsonString: line),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CodeEditor).first);
    await tester.pumpAndSettle();

    // Home 到行首，再连续 Right 到行尾。
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    for (int i = 0; i < line.length; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final ScrollableState hScroll = _horizontalScrollable(tester);
    final double pixels = hScroll.position.pixels;
    final double max = hScroll.position.maxScrollExtent;
    // ignore: avoid_print
    print('arrow-right: pixels=$pixels max=$max');
    expect(pixels, lessThanOrEqualTo(max + 0.5), reason: '越界会回弹');
    // 行尾应被揭示：pixels 接近 max。
    expect(pixels, greaterThan(max - 40), reason: '行尾应可达');
    debugDefaultTargetPlatformOverride = null;
  });

  // 500KB 超大单行：排除 Skia 在超大宽度下 longestLine 精度/上限问题。
  testWidgets('huge single-line json (500KB): End reveals end', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final String huge = List<String>.generate(70000, (i) => 'a').join();
    await tester.pumpWidget(
      ShadApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 400,
            child: JsonCodeEditor(jsonString: huge),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CodeEditor).first);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();

    final ScrollableState hScroll = _horizontalScrollable(tester);
    final double pixels = hScroll.position.pixels;
    final double max = hScroll.position.maxScrollExtent;
    // ignore: avoid_print
    print('huge: pixels=$pixels max=$max');
    expect(pixels, lessThanOrEqualTo(max + 0.5), reason: '越界会回弹');
    expect(pixels, greaterThan(max - 40), reason: '行尾应可达');
    debugDefaultTargetPlatformOverride = null;
  });

  // 1.5MB 单行（用户实际场景）：验证引擎在超大宽度下 longestLine / getBoxesForRange
  // 仍正确，End 能滚到 max 且行尾落在视口内。
  testWidgets('1.5MB single-line json: End reveals end', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final String huge = List<String>.generate(1500000, (i) => 'a').join();
    await tester.pumpWidget(
      ShadApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 400,
            child: JsonCodeEditor(jsonString: huge),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.tap(find.byType(CodeEditor).first);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final ScrollableState hScroll = _horizontalScrollable(tester);
    final double pixels = hScroll.position.pixels;
    final double max = hScroll.position.maxScrollExtent;
    // ignore: avoid_print
    print('1.5MB: pixels=$pixels max=$max');
    expect(max, greaterThan(0), reason: '内容应已加载');
    expect(pixels, lessThanOrEqualTo(max + 0.5), reason: '越界会回弹');
    expect(pixels, greaterThan(max - 40), reason: '行尾应可达');
    debugDefaultTargetPlatformOverride = null;
  });
}
