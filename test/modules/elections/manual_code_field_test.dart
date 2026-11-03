import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/elections/presentation/widgets/manual_code_field.dart';

Future<List<String>> pumpField(WidgetTester tester) async {
  final received = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ManualCodeField(onElectionId: received.add)),
    ),
  );
  return received;
}

Future<void> submit(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.byType(FilledButton));
  await tester.pump();
}

void main() {
  testWidgets('link de votação chama o callback com o id', (tester) async {
    final received = await pumpField(tester);

    await submit(tester, 'https://x.com/votar/abc12345XYZ');

    expect(received, ['abc12345XYZ']);
    expect(find.text('Código ou link inválido.'), findsNothing);
  });

  testWidgets('texto qualquer mostra a mensagem e não chama', (tester) async {
    final received = await pumpField(tester);

    await submit(tester, 'oi');

    expect(received, isEmpty);
    expect(find.text('Código ou link inválido.'), findsOneWidget);
  });

  testWidgets('link de condução não serve para votar', (tester) async {
    final received = await pumpField(tester);

    await submit(tester, 'https://x.com/eleicoes/abc12345XYZ');

    expect(received, isEmpty);
    expect(find.text('Código ou link inválido.'), findsOneWidget);
  });

  testWidgets('a mensagem some quando o valor passa a ser válido', (
    tester,
  ) async {
    final received = await pumpField(tester);

    await submit(tester, 'oi');
    await submit(tester, 'abc12345XYZ');

    expect(received, ['abc12345XYZ']);
    expect(find.text('Código ou link inválido.'), findsNothing);
  });
}
