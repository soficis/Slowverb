import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:slowverb_web/features/import/import_screen.dart';

void main() {
  testWidgets('renders import screen header', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: ImportScreen()));
    await tester.pump();

    expect(find.text('SLOWVERB'), findsOneWidget);
    expect(find.text('Slowed + Reverb Editor'), findsOneWidget);
  });
}
