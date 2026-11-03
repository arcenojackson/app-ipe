import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/elections/models/election.dart';
import 'package:ipe_flutter/src/modules/elections/presentation/widgets/election_ballot.dart';

ElectionRound roundOf(int number) => ElectionRound(
  id: 'r$number',
  position: 'presidente',
  cycle: 1,
  number: number,
  status: RoundStatus.open,
  options: const [
    Candidate(id: 'c1', name: 'Ana'),
    Candidate(id: 'c2', name: 'Bruno'),
  ],
  votedCount: 0,
);

Future<void> pump(
  WidgetTester tester, {
  required ElectionRound round,
  bool busy = false,
  String? error,
  ValueChanged<String>? onSubmit,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ElectionBallot(
          round: round,
          busy: busy,
          error: error,
          onSubmit: onSubmit ?? (_) {},
        ),
      ),
    ),
  ),
);

// Por tipo: ocupado, o botão mostra um indicador em vez do texto.
Finder confirmButton() => find.byType(FilledButton);

bool isEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(confirmButton()).onPressed != null;

void main() {
  testWidgets('1º escrutínio lista as opções, o branco e a busca', (
    tester,
  ) async {
    await pump(tester, round: roundOf(1));

    expect(find.text('Buscar por nome'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Bruno'), findsOneWidget);
    expect(find.text('Branco'), findsOneWidget);
    expect(find.textContaining('Presidente'), findsOneWidget);
  });

  testWidgets('a busca filtra as opções e mantém o branco', (tester) async {
    await pump(tester, round: roundOf(1));

    await tester.enterText(find.byType(TextField), 'ana');
    await tester.pump();

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Bruno'), findsNothing);
    expect(find.text('Branco'), findsOneWidget);
  });

  testWidgets('só habilita Confirmar depois de escolher', (tester) async {
    await pump(tester, round: roundOf(1));
    expect(isEnabled(tester), isFalse);

    await tester.tap(find.text('Ana'));
    await tester.pump();
    expect(isEnabled(tester), isTrue);
  });

  testWidgets('confirmar envia o id do candidato escolhido', (tester) async {
    String? sent;
    await pump(tester, round: roundOf(1), onSubmit: (c) => sent = c);

    await tester.tap(find.text('Bruno'));
    await tester.pump();
    await tester.tap(confirmButton());

    expect(sent, 'c2');
  });

  testWidgets('escolher Branco envia "blank"', (tester) async {
    String? sent;
    await pump(tester, round: roundOf(1), onSubmit: (c) => sent = c);

    await tester.tap(find.text('Branco'));
    await tester.pump();
    await tester.tap(confirmButton());

    expect(sent, 'blank');
  });

  testWidgets('2º escrutínio não tem busca', (tester) async {
    await pump(tester, round: roundOf(2));

    expect(find.text('Buscar por nome'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('enviando, o botão fica desabilitado', (tester) async {
    await pump(tester, round: roundOf(1));
    await tester.tap(find.text('Ana'));
    await tester.pump();

    await pump(tester, round: roundOf(1), busy: true);
    expect(isEnabled(tester), isFalse);
  });

  testWidgets('erro do servidor aparece e o botão volta a habilitar', (
    tester,
  ) async {
    await pump(tester, round: roundOf(1), busy: true);
    await pump(tester, round: roundOf(1), error: 'Rodada encerrada');

    expect(find.text('Rodada encerrada'), findsOneWidget);
    await tester.tap(find.text('Ana'));
    await tester.pump();
    expect(isEnabled(tester), isTrue);
  });

  testWidgets(
    'a escolha some se a busca a esconde (não envia voto invisível)',
    (tester) async {
      await pump(tester, round: roundOf(1));

      await tester.tap(find.text('Ana'));
      await tester.pump();
      expect(isEnabled(tester), isTrue);

      await tester.enterText(find.byType(TextField), 'bru');
      await tester.pump();

      expect(find.text('Ana'), findsNothing);
      expect(isEnabled(tester), isFalse);
    },
  );

  testWidgets('a escolha continua se a busca ainda a mostra', (tester) async {
    await pump(tester, round: roundOf(1));

    await tester.tap(find.text('Bruno'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'bru');
    await tester.pump();

    expect(isEnabled(tester), isTrue);
  });
}
