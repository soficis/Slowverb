import 'package:flutter_test/flutter_test.dart';
import 'package:slowverb_web/app/app.dart';

void main() {
  testWidgets('renders Slowverb import screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SlowverbApp());
    await tester.pumpAndSettle();

    expect(find.text('SLOWVERB'), findsWidgets);
    expect(find.textContaining('Slowed + Reverb'), findsOneWidget);
  });
}
