import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/elections/data/elections_repository.dart';
import 'package:ipe_flutter/src/modules/elections/models/election.dart';
import 'package:ipe_flutter/src/modules/elections/presentation/widgets/election_form_sheet.dart';
import 'package:ipe_flutter/src/modules/societies/data/societies_repository.dart';
import 'package:ipe_flutter/src/modules/societies/models/society.dart';
import 'package:ipe_flutter/src/shared/state/app_state.dart';
import 'package:provider/provider.dart';

import 'election_test_fakes.dart';

class FakeSocieties extends Fake implements SocietiesRepository {
  @override
  Future<List<SocietyModel>> fetchAll() async => const [
    SocietyModel(
      id: 's1',
      name: 'UMP',
      description: '',
      color: 0xFF000000,
      userId: 'u1',
      boardIds: ['u1'],
    ),
  ];
}

class FakeElections extends Fake implements ElectionsRepository {
  ElectionEligibility? sent;

  @override
  Future<String> createElection({
    required String societyId,
    required String title,
    required DateTime scheduledAt,
    required List<String> positions,
    ElectionEligibility eligibility = ElectionEligibility.all,
  }) async {
    sent = eligibility;
    return 'e1';
  }
}

Future<FakeElections> openForm(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeElections();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<SocietiesRepository>.value(value: FakeSocieties()),
        Provider<ElectionsRepository>.value(value: repo),
        ChangeNotifierProvider<AppState>.value(value: FakeAppState()),
      ],
      child: const MaterialApp(home: Scaffold(body: ElectionFormSheet())),
    ),
  );
  await tester.pumpAndSettle();
  // Escolhe a sociedade (o título é preenchido sozinho).
  await tester.tap(find.byType(DropdownButtonFormField<SocietyModel>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('UMP').last);
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets(
    'pergunta quem estará apto a ser votado, antes de Criar eleição',
    (tester) async {
      await openForm(tester);

      expect(find.text('Quem estará apto a ser votado?'), findsOneWidget);
      expect(find.text('Todos os membros do grupo'), findsOneWidget);
      expect(find.text('Apenas os presentes na votação'), findsOneWidget);
    // Sem texto explicativo embaixo das opções.
    expect(find.textContaining('Só quem já entrou'), findsNothing);
      expect(
        tester.getRect(find.text('Quem estará apto a ser votado?')).bottom,
        lessThan(tester.getRect(find.text('Criar eleição')).top),
      );
    },
  );

  testWidgets('por padrão envia "todos os membros"', (tester) async {
    final repo = await openForm(tester);

    await tester.tap(find.text('Criar eleição'));
    await tester.pumpAndSettle();

    expect(repo.sent, ElectionEligibility.all);
  });

  testWidgets('"Apenas os presentes" é enviado ao criar', (tester) async {
    final repo = await openForm(tester);

    await tester.tap(find.text('Apenas os presentes na votação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar eleição'));
    await tester.pumpAndSettle();

    expect(repo.sent, ElectionEligibility.present);
  });
}
