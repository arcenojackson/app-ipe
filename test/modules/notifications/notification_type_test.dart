import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/notifications/models/notification_type.dart';

void main() {
  test('eleição aberta é um tipo de notificação que o usuário pode desativar',
      () {
    expect(
      NotificationType.fromId('election_open'),
      NotificationType.electionOpen,
    );
    expect(NotificationType.electionOpen.id, 'election_open');
    expect(NotificationType.electionOpen.title, 'Eleição aberta');
  });
}
