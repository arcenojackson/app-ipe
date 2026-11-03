import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/core/utils/app_exception.dart';
import 'package:ipe_flutter/src/modules/elections/data/elections_repository.dart';
import 'package:ipe_flutter/src/modules/elections/models/election.dart';
import 'package:ipe_flutter/src/modules/elections/models/election_logic.dart';
import 'package:ipe_flutter/src/modules/elections/presentation/election_detail_page.dart';
import 'package:ipe_flutter/src/shared/state/app_state.dart';
import 'package:provider/provider.dart';

import 'election_test_fakes.dart';

class FakeRepo extends Fake implements ElectionsRepository {
  final election = StreamController<Election?>.broadcast();
  final opened = <String>[];
  Object? openError;

  @override
  Stream<Election?> watchElection(String id) => election.stream;

  // A ata só precisa de listas (vazias) para sair do "carregando".
  @override
  Stream<List<ElectionCargo>> watchCargos(String id) => Stream.value(const []);

  @override
  Stream<List<ElectionVoter>> watchVoters(String id) => Stream.value(const []);

  @override
  Stream<List<ElectionRound>> watchRounds(String id) => Stream.value(const []);

  @override
  Stream<List<ElectionEvent>> watchEvents(String id) => Stream.value(const []);

  @override
  Future<void> openElection(String electionId) async {
    final error = openError;
    if (error != null) throw error;
    opened.add(electionId);
  }
}

Election electionWith(
  ElectionStatus status, {
  List<String> directorIds = const ['u1'],
}) => Election(
  id: 'e1',
  societyId: 's1',
  societyName: 'UMP',
  title: 'Eleição UMP 2026',
  scheduledAt: DateTime(2026, 11, 8),
  status: status,
  positions: const ['presidente'],
  directorIds: directorIds,
);

Future<FakeRepo> openDetail(WidgetTester tester, Election election) async {
  final repo = FakeRepo();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ElectionsRepository>.value(value: repo),
        ChangeNotifierProvider<AppState>.value(value: FakeAppState()),
      ],
      child: const MaterialApp(home: ElectionDetailPage(electionId: 'e1')),
    ),
  );
  repo.election.add(election);
  await tester.pump();
  await tester.pump();
  return repo;
}

// Os botões são subtipos de ButtonStyleButton: casa por predicado.
final startButton = find.ancestor(
  of: find.text('Iniciar votação'),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);

void main() {
  testWidgets('rascunho: o diretor vê o botão Iniciar votação', (tester) async {
    await openDetail(tester, electionWith(ElectionStatus.draft));

    expect(startButton, findsOneWidget);
  });

  testWidgets('eleição aberta ou encerrada não mostra o botão', (tester) async {
    final repo = await openDetail(tester, electionWith(ElectionStatus.open));
    expect(startButton, findsNothing);

    repo.election.add(electionWith(ElectionStatus.closed));
    await tester.pump();
    await tester.pump();
    expect(startButton, findsNothing);
  });

  testWidgets('quem não é diretor da eleição não vê o botão', (tester) async {
    await openDetail(
      tester,
      electionWith(ElectionStatus.draft, directorIds: const ['outro']),
    );

    expect(startButton, findsNothing);
  });

  testWidgets('cancelar a confirmação não abre a eleição', (tester) async {
    final repo = await openDetail(tester, electionWith(ElectionStatus.draft));

    await tester.tap(startButton);
    await tester.pumpAndSettle();
    expect(find.text('Iniciar a votação?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repo.opened, isEmpty);
  });

  testWidgets('confirmar abre a eleição uma única vez', (tester) async {
    final repo = await openDetail(tester, electionWith(ElectionStatus.draft));

    await tester.tap(startButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Iniciar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(repo.opened, ['e1']);
  });

  testWidgets('erro do servidor não derruba a tela e o botão continua', (
    tester,
  ) async {
    final repo = await openDetail(tester, electionWith(ElectionStatus.draft));
    repo.openError = AppException(message: 'Só diretores podem iniciar.');

    await tester.tap(startButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Iniciar'));
    await tester.pump();
    expect(find.text('Só diretores podem iniciar.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(repo.opened, isEmpty);
    expect(startButton, findsOneWidget);
  });

  testWidgets('copia o link da condução para o diretor abrir no computador', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await openDetail(tester, electionWith(ElectionStatus.open));

    await tester.tap(find.text('Link da condução'));
    await tester.pump();

    expect(copied, buildConductLink('e1'));
    expect(find.text('Link da condução copiado.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('não repete sociedade e data acima do status', (tester) async {
    await openDetail(tester, electionWith(ElectionStatus.open));

    expect(find.text('UMP · 08/11/2026 00:00'), findsNothing);
    expect(find.text('Em andamento'), findsOneWidget);
  });

  testWidgets('os dois links ficam juntos, sem botões soltos de copiar', (
    tester,
  ) async {
    await openDetail(tester, electionWith(ElectionStatus.draft));

    expect(find.text('Link da condução'), findsOneWidget);
    expect(find.text('Link da votação'), findsOneWidget);
    expect(find.text('Copiar link da votação'), findsNothing);
    expect(find.text('Iniciar votação'), findsOneWidget);
    expect(find.text('Abrir na web'), findsOneWidget);
  });

  Rect rectOfButton(WidgetTester tester, String text) => tester.getRect(
    find.ancestor(
      of: find.text(text),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    ),
  );

  void narrowScreen(WidgetTester tester) {
    // 360 dp: o texto longo não pode estourar o quadrado.
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('rascunho: abrir na web à esquerda (cheio) e iniciar à direita '
      '(contorno), os dois quadrados', (tester) async {
    narrowScreen(tester);
    await openDetail(tester, electionWith(ElectionStatus.draft));

    final web = rectOfButton(tester, 'Abrir na web');
    final start = rectOfButton(tester, 'Iniciar votação');

    expect(web.top, start.top);
    expect(web.left, lessThan(start.left));
    expect(web.width, closeTo(web.height, 1));
    expect(start.width, closeTo(start.height, 1));
    expect(
      find.ancestor(
        of: find.text('Abrir na web'),
        matching: find.byType(FilledButton),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Iniciar votação'),
        matching: find.byType(OutlinedButton),
      ),
      findsOneWidget,
    );
  });

  testWidgets('depois do rascunho: abrir na web e os links de copiar ocupam '
      'os dois quadrados', (tester) async {
    narrowScreen(tester);
    await openDetail(tester, electionWith(ElectionStatus.open));

    final web = rectOfButton(tester, 'Abrir na web');
    final links = tester.getRect(find.byKey(const ValueKey('links-card')));

    expect(web.top, links.top);
    expect(web.left, lessThan(links.left));
    expect(links.width, closeTo(links.height, 1));
    expect(find.text('Link da condução'), findsOneWidget);
    expect(find.text('Link da votação'), findsOneWidget);
    expect(find.text('Iniciar votação'), findsNothing);
    // Mesmo compactos, os links mantêm o ícone de corrente.
    expect(find.byIcon(Icons.link), findsNWidgets(2));
  });

  testWidgets('em rascunho os links ficam num cartão abaixo dos botões', (
    tester,
  ) async {
    narrowScreen(tester);
    await openDetail(tester, electionWith(ElectionStatus.draft));

    final web = rectOfButton(tester, 'Abrir na web');
    final links = tester.getRect(find.byKey(const ValueKey('links-card')));

    expect(links.top, greaterThan(web.bottom));
    expect(find.text('Link da condução'), findsOneWidget);
  });

  testWidgets('o status é pequeno, à direita e tem uma cor por situação', (
    tester,
  ) async {
    narrowScreen(tester);
    final repo = await openDetail(tester, electionWith(ElectionStatus.draft));

    Color colorOf(String label) {
      final text = tester.widget<Text>(find.text(label));
      return text.style!.color!;
    }

    final draftColor = colorOf('Rascunho');
    expect(tester.getRect(find.text('Rascunho')).right, greaterThan(300));

    repo.election.add(electionWith(ElectionStatus.open));
    await tester.pump();
    await tester.pump();
    final openColor = colorOf('Em andamento');

    repo.election.add(electionWith(ElectionStatus.closed));
    await tester.pump();
    await tester.pump();
    final closedColor = colorOf('Encerrada');

    expect({draftColor, openColor, closedColor}, hasLength(3));
  });

  testWidgets('"Copiar ata" é o botão primário, de largura total', (
    tester,
  ) async {
    narrowScreen(tester);
    await openDetail(tester, electionWith(ElectionStatus.open));

    final button = find.ancestor(
      of: find.text('Copiar ata'),
      // FilledButton.icon é um subtipo: casa por predicado, não por tipo exato.
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    );
    expect(button, findsOneWidget);
    // Largura da tela (360) menos o padding de 16 de cada lado.
    expect(tester.getRect(button).width, closeTo(328, 1));
  });

  testWidgets('eleição concluída: abrir na web e os links ficam bloqueados', (
    tester,
  ) async {
    narrowScreen(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await openDetail(tester, electionWith(ElectionStatus.completed));

    final web = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Abrir na web'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(web.onPressed, isNull);

    for (final copy in tester.widgetList<IconButton>(find.byType(IconButton))) {
      // Só os botões de copiar (a seta de voltar não existe nesta tela).
      expect(copy.onPressed, isNull);
    }
    await tester.tap(find.text('Link da condução'));
    await tester.tap(find.text('Link da votação'));
    await tester.pump();
    expect(copied, isNull);
    // A ata continua copiável.
    expect(find.text('Copiar ata'), findsOneWidget);
  });

  testWidgets('eleição não concluída mantém os botões ativos', (tester) async {
    await openDetail(tester, electionWith(ElectionStatus.closed));

    final web = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Abrir na web'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(web.onPressed, isNotNull);
  });
}
