import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/state/app_state.dart';
import '../../../shared/utils/app_toast.dart';
import '../../notifications/services/teaching_notification_url.dart';
import '../data/forum_repository.dart';
import '../models/forum_logic.dart';
import '../models/forum_models.dart';
import 'forum_editor_page.dart';
import 'forum_topic_controller.dart';
import 'widgets/comment_composer.dart';
import 'widgets/comment_tile.dart';
import 'widgets/forum_scaffold.dart';
import 'widgets/linkified_text.dart';
import 'widgets/ref_card.dart';

const forumPortalTopicBase = 'https://ipe-ensino.vercel.app/ensino/forum/';

class ForumTopicPage extends StatefulWidget {
  const ForumTopicPage({
    super.key,
    required this.topicId,
    required this.viewer,
    this.openPortalIfMissing = false,
  });

  final String topicId;
  final ForumViewer viewer;

  /// Aberto por push: se o tópico não existir, cai no portal (navegador).
  final bool openPortalIfMissing;

  @override
  State<ForumTopicPage> createState() => _ForumTopicPageState();
}

class _ForumTopicPageState extends State<ForumTopicPage> {
  late final ForumTopicController _controller;
  ForumComment? _replyTo;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().currentUser;
    _controller = ForumTopicController(
      repository: context.read<ForumRepository>(),
      topicId: widget.topicId,
      viewer: widget.viewer,
      author: ForumAuthor(uid: widget.viewer.uid, name: user?.name ?? ''),
    )..addListener(_onChange);
    _start();
  }

  Future<void> _start() async {
    try {
      // Atualiza as claims uma vez: o papel pode ter mudado há pouco.
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (_) {}
    await _controller.load();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    final c = _controller;
    if (c.notFound && widget.openPortalIfMissing) {
      launchUrl(Uri.parse('$forumPortalTopicBase${widget.topicId}'),
          mode: LaunchMode.externalApplication);
      Navigator.of(context).pop();
      return;
    }
    final err = c.actionError;
    if (err != null) {
      c.clearActionError();
      showErrorToast(context, err);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openOnWeb() async {
    final uri = teachingPortalTopicUri(widget.topicId);
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    if (!opened && mounted) {
      showErrorToast(context, 'Não foi possível abrir o tópico na web.');
    }
  }

  Future<bool> _confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(text),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirmar')),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final t = c.topic;
    final perms = c.permissions;
    final actions = <Widget>[];
    if (t != null && perms != null) {
      actions.add(PopupMenuButton<String>(
        iconColor: Colors.white,
        onSelected: (v) async {
          switch (v) {
            case 'web':
              await _openOnWeb();
            case 'edit':
              final id = await Navigator.of(context).push<String>(MaterialPageRoute(
                builder: (_) => ForumEditorPage(viewer: widget.viewer, editing: t),
              ));
              if (id != null) c.load();
            case 'pin':
              await c.togglePin();
            case 'lock':
              await c.toggleLock();
            case 'delete':
              final navigator = Navigator.of(context);
              if (await _confirm('Apagar este tópico?') && await c.deleteTopic()) {
                navigator.pop();
              }
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'web',
            child: Row(children: [
              Icon(Icons.open_in_new, size: 18),
              SizedBox(width: 8),
              Text('Abrir na web'),
            ]),
          ),
          if (perms.canEdit) const PopupMenuItem(value: 'edit', child: Text('Editar')),
          if (perms.canPin)
            PopupMenuItem(value: 'pin', child: Text(t.pinned ? 'Desafixar' : 'Fixar')),
          if (perms.canLock)
            PopupMenuItem(value: 'lock', child: Text(t.locked ? 'Destrancar' : 'Trancar')),
          if (perms.canDelete) const PopupMenuItem(value: 'delete', child: Text('Apagar')),
        ],
      ));
    }
    return ForumScaffold(
      title: 'Tópico',
      actions: actions,
      child: _body(c),
    );
  }

  Widget _body(ForumTopicController c) {
    if (c.loading && c.topic == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (c.notFound) {
      return const Center(
        child: Text('Tópico não encontrado.', style: TextStyle(color: Colors.white70)),
      );
    }
    final t = c.topic;
    if (c.error || t == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Não foi possível carregar o tópico.',
              style: TextStyle(color: Colors.white70)),
          TextButton(onPressed: c.load, child: const Text('Tentar de novo')),
        ]),
      );
    }
    final perms = c.permissions!;
    final theme = Theme.of(context);
    final tree = buildCommentTree(c.comments);
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(t.title,
            style: theme.textTheme.titleLarge
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          '${t.authorName} · ${forumDate(t.createdAt)}${t.editedAt != null ? ' · editado' : ''}'
          '${t.pinned ? ' · Fixado' : ''}${t.locked ? ' · Trancado' : ''}${t.deleted ? ' · Removido' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
        ),
        const SizedBox(height: 12),
        if (perms.visibleBody)
          LinkifiedText(t.body,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white))
        else
          const Text('Tópico removido.', style: TextStyle(color: Colors.white54)),
        for (final ref in t.refs) RefCard(ref: ref),
        const Divider(height: 32, color: Colors.white24),
        Text('Comentários (${c.comments.where((x) => !x.deleted).length})',
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
        for (final node in tree)
          CommentTile(
            node: node,
            perms: c.commentPerms,
            myVotes: c.myVotes,
            onVote: (cm, v) => c.vote(cm, v),
            replyingToId: _replyTo?.id,
            onReply: (cm) => setState(() => _replyTo = cm),
            onEdit: (cm, text) => c.editComment(cm, text),
            onDelete: (cm) async {
              if (await _confirm('Apagar este comentário?')) await c.deleteComment(cm);
            },
          ),
      ],
    );
    final reply = _replyTo;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: Theme.of(context).colorScheme.secondary,
            backgroundColor: const Color(0xFF111828),
            onRefresh: c.refresh,
            child: list,
          ),
        ),
        if (perms.canComment)
          Material(
            color: const Color(0xFF111828),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Column(
                  children: [
                    // Os dois ficam montados: trocar de modo preserva os rascunhos.
                    Offstage(
                      offstage: reply != null,
                      child: CommentComposer(
                        key: const ValueKey('topic-composer'),
                        allowRefs: true,
                        header: const _ComposerHeader('Novo comentário'),
                        onSubmit: (text, refs) => c.submitComment(text, null, refs: refs),
                      ),
                    ),
                    if (reply != null)
                      CommentComposer(
                        key: ValueKey('reply-${reply.id}'),
                        allowRefs: true,
                        submitLabel: 'Responder',
                        hint: 'Escreva uma resposta',
                        header: _ComposerHeader('Respondendo a ${reply.authorName}',
                            quote: reply.body),
                        onCancel: () => setState(() => _replyTo = null),
                        onSubmit: (text, refs) async {
                          final ok = await c.submitComment(text, reply, refs: refs);
                          if (ok && mounted) setState(() => _replyTo = null);
                          return ok;
                        },
                      ),
                  ],
                ),
              ),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Este tópico não aceita novos comentários.',
                style: TextStyle(color: Colors.white54)),
          ),
      ],
    );
  }
}

class _ComposerHeader extends StatelessWidget {
  const _ComposerHeader(this.title, {this.quote});

  final String title;
  final String? quote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          if (quote != null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Colors.white38, width: 2)),
              ),
              child: Text(quote!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
