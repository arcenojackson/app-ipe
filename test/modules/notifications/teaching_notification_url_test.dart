import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/notifications/services/teaching_notification_url.dart';

void main() {
  group('teachingPortalUriFromData', () {
    const valid = 'https://ipe-ensino.vercel.app/ensino/biblioteca?item=abc123';

    test(
      'abre o item do portal quando o tipo e o endereço são os esperados',
      () {
        final uri = teachingPortalUriFromData({
          'type': 'teaching_review',
          'url': valid,
        });
        expect(uri, isNotNull);
        expect(uri.toString(), valid);
      },
    );

    test('ignora outros tipos de notificação', () {
      expect(
        teachingPortalUriFromData({'type': 'chat_mention', 'url': valid}),
        isNull,
      );
      expect(teachingPortalUriFromData({'url': valid}), isNull);
    });

    test(
      'recusa endereço de outro host, inclusive truques de subdomínio e usuário',
      () {
        for (final bad in [
          'https://evil.com/ensino/biblioteca',
          'https://ipe-ensino.vercel.app.evil.com/x',
          'https://ipe-ensino.vercel.app@evil.com/x',
          'https://evil.com/?u=ipe-ensino.vercel.app',
        ]) {
          expect(
            teachingPortalUriFromData({'type': 'teaching_review', 'url': bad}),
            isNull,
            reason: bad,
          );
        }
      },
    );

    test('recusa http, esquemas estranhos, vazio, ausente e tipo errado', () {
      for (final bad in [
        'http://ipe-ensino.vercel.app/x',
        'javascript:alert(1)',
        '',
        'não é uma url',
      ]) {
        expect(
          teachingPortalUriFromData({'type': 'teaching_review', 'url': bad}),
          isNull,
          reason: bad,
        );
      }
      expect(teachingPortalUriFromData({'type': 'teaching_review'}), isNull);
      expect(
        teachingPortalUriFromData({'type': 'teaching_review', 'url': 42}),
        isNull,
      );
    });
  });
}
