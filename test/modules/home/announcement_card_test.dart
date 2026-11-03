import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/home/presentation/widgets/announcement_card.dart';

void main() {
  testWidgets('mostra título e subtítulo e responde ao toque', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnouncementCard(
            icon: Icons.how_to_vote_rounded,
            title: 'Eleição aberta!',
            subtitle: 'Eleição UMP 2026 · UMP',
            onTap: () => taps++,
          ),
        ),
      ),
    );

    expect(find.text('Eleição aberta!'), findsOneWidget);
    expect(find.text('Eleição UMP 2026 · UMP'), findsOneWidget);
    expect(find.byIcon(Icons.how_to_vote_rounded), findsOneWidget);

    await tester.tap(find.text('Eleição aberta!'));
    expect(taps, 1);
  });
}
