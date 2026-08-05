import 'package:flutter_test/flutter_test.dart';
import 'package:myzip/main.dart';

void main() {
  testWidgets('App load test', (WidgetTester tester) async {

    await tester.pumpWidget(const PropertyApp());
  });
}