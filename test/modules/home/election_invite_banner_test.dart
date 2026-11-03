import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/elections/data/elections_repository.dart';
import 'package:ipe_flutter/src/modules/elections/models/election.dart';
import 'package:ipe_flutter/src/modules/home/presentation/widgets/election_invite_banner.dart';
import 'package:provider/provider.dart';

/// Cada chamada de `watchOpenInvites` devolve um stream novo, como o real.
class FakeRepo extends Fake implements ElectionsRepository {
  final streams = <StreamController<List<ElectionInvite>>>[];

  @override
  Stream<List<ElectionInvite>> watchOpenInvites(String uid) {
    final controller = StreamController<List<ElectionInvite>>();
    streams.add(controller);
    return controller.stream;
  }
}

const invite = ElectionInvite(
  id: 'e1',
  title: 'Eleição UMP 2026',
  societyName: 'UMP',
);

Future<FakeRepo> pumpBanner(WidgetTester tester) async {
  final repo = FakeRepo();
  await tester.pumpWidget(
    Provider<ElectionsRepository>.value(
      value: repo,
      child: const MaterialApp(
        home: Scaffold(
          body: ElectionInviteBanner(
            uid: 'u1',
            retryDelay: Duration(seconds: 1),
          ),
        ),
      ),
    ),
  );
  return repo;
}

void main() {
  testWidgets('mostra o balão quando chega um convite', (tester) async {
    final repo = await pumpBanner(tester);

    repo.streams.single.add([invite]);
    await tester.pump();

    expect(find.text('Eleição aberta!'), findsOneWidget);
  });

  testWidgets(
    'volta a ouvir depois de um erro (ex.: regras ainda sem efeito)',
    (tester) async {
      final repo = await pumpBanner(tester);

      repo.streams.single.addError(StateError('permission-denied'));
      await tester.pump();
      expect(find.text('Eleição aberta!'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(repo.streams, hasLength(2));

      repo.streams.last.add([invite]);
      await tester.pump();
      await tester.pump();
      expect(find.text('Eleição aberta!'), findsOneWidget);
    },
  );

  testWidgets('ao voltar para o app, ouve de novo', (tester) async {
    final repo = await pumpBanner(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(repo.streams, hasLength(2));
    repo.streams.last.add([invite]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Eleição aberta!'), findsOneWidget);
  });
}
