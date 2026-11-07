import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slowverb_web/features/editor/widgets/effect_slider.dart';

void main() {
  Future<List<double>> pump(WidgetTester tester) async {
    final changes = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EffectSlider(
            label: 'Reverb',
            value: 0.5,
            min: 0,
            max: 1,
            unit: '%',
            formatValue: (v) => '${(v * 100).round()}%',
            onChanged: changes.add,
          ),
        ),
      ),
    );
    return changes;
  }

  testWidgets('slider exposes label and formatted value to semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    final node = tester.getSemantics(find.byType(Slider));
    final data = node.getSemanticsData();
    expect(data.label, contains('Reverb'));
    expect(data.label + data.value, contains('50%'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.increase), isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.decrease), isTrue);
    handle.dispose();
  });

  testWidgets('typed value is clamped to range', (tester) async {
    final changes = await pump(tester);
    await tester.tap(find.text('50%'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.text('Set'));
    await tester.pumpAndSettle();
    expect(changes, [1.0]);
  });

  testWidgets('invalid input shows error and keeps old value', (tester) async {
    final changes = await pump(tester);
    await tester.tap(find.text('50%'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.text('Set'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter a number'), findsOneWidget);
    expect(changes, isEmpty);
  });
}
