import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/auth/models/user.dart';
import 'package:ipe_flutter/src/modules/notifications/models/notification_type.dart';
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

  group('resolveTeachingTap', () {
    const forumUrl = 'https://ipe-ensino.vercel.app/ensino/forum/top1';
    Map<String, dynamic> push({String type = 'teaching_forum', Object? topicId = 'top1', Object? url = forumUrl}) =>
        {'type': type, 'topicId': topicId, 'url': url};
    UserModel user({TeachingRole role = TeachingRole.none, bool admin = false}) => UserModel(
        id: 'u', name: 'N', email: 'e@e.com', isAdmin: admin, isPending: false, teachingRole: role);

    test('professor abre o tópico no app', () {
      final tap = resolveTeachingTap(push(), user(role: TeachingRole.teacher));
      expect(tap, isA<OpenTopic>());
      expect((tap as OpenTopic).topicId, 'top1');
    });

    test('admin sem papel de ensino cai no navegador', () {
      final tap = resolveTeachingTap(push(), user(admin: true));
      expect(tap, isA<OpenBrowser>());
      expect((tap as OpenBrowser).uri.toString(), forumUrl);
    });

    test('sem usuário cai no navegador', () {
      expect(resolveTeachingTap(push(), null), isA<OpenBrowser>());
    });

    test('topicId inválido nunca abre tópico', () {
      final teacher = user(role: TeachingRole.teacher);
      for (final bad in ['', '../x', 'a/b', 'x' * 129, 5, null]) {
        expect(resolveTeachingTap(push(topicId: bad), teacher), isNot(isA<OpenTopic>()));
      }
    });

    test('url de outro host, http ou com usuário é ignorada', () {
      for (final bad in [
        'https://evil.com/ensino/forum/top1',
        'http://ipe-ensino.vercel.app/ensino/forum/top1',
        'https://x@ipe-ensino.vercel.app/ensino/forum/top1',
        'https://ipe-ensino.vercel.app.evil.com/x',
        null,
      ]) {
        expect(resolveTeachingTap(push(url: bad), user(admin: true)), isA<IgnoreTap>());
      }
    });

    test('revisão continua abrindo o navegador e outros tipos são ignorados', () {
      final review = resolveTeachingTap({
        'type': 'teaching_review',
        'url': 'https://ipe-ensino.vercel.app/ensino/biblioteca?item=a',
      }, null);
      expect(review, isA<OpenBrowser>());
      expect(resolveTeachingTap({'type': 'chat_mention', 'url': forumUrl}, null), isA<IgnoreTap>());
      expect(teachingForumTopicIdFromData({'type': 'chat_mention', 'topicId': 'a'}), isNull);
    });

    test('tipo de notificação teaching_forum existe para a preferência', () {
      expect(NotificationType.fromId('teaching_forum'), NotificationType.teachingForum);
    });
  });
}
