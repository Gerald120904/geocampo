import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocampo_app/app/geocampo_app.dart';

void main() {
  testWidgets('GeoCampo shows splash branding', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GeoCampoApp()));
    expect(find.text('GeoCampo'), findsOneWidget);
    expect(find.text('Mapas de campo offline'), findsOneWidget);
  });
}
