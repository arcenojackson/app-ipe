import 'package:flutter/material.dart';

import '../../models/forum_logic.dart';
import '../../models/forum_models.dart';
import 'comment_composer.dart';
import 'forum_scaffold.dart';
import 'linkified_text.dart';
import 'ref_card.dart';

class CommentTile extends StatefulWidget {
  const CommentTile({
    super.key,
    required this.node,
    required this.perms,
    required this.myVotes,
    required this.onVote,
    required this.onReply,
    this.replyingToId,
    required this.onEdit,
    required this.onDelete,
  });

  final CommentNode node;
  final CommentPermissions Function(ForumComment) perms;
  final Map<String, int> myVotes;
  final void Function(ForumComment, int) onVote;
  final void Function(ForumComment) onReply;

  /// Comentário que está sendo respondido (destacado enquanto o composer de resposta está aberto).
  final String? replyingToId;
  final Future<bool> Function(ForumComment, String) onEdit;
  final Future<void> Function(ForumComment) onDelete;

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.node.comment;
    final p = widget.perms(c);
    final mine = widget.myVotes[c.id];
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(left: c.depth > 1 ? 14 : 0, top: 10),
      child: Container(
        decoration: BoxDecoration(
          color: widget.replyingToId == c.id ? Colors.white10 : null,
          border: c.depth > 1
              ? const Border(left: BorderSide(color: Colors.white24, width: 2))
              : null,
        ),
        padding: EdgeInsets.only(left: c.depth > 1 ? 10 : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${c.authorName} · ${forumDate(c.createdAt)}${c.editedAt != null ? ' · editado' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
            const SizedBox(height: 4),
            if (c.deleted)
              Text('Comentário removido',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white38, fontStyle: FontStyle.italic))
            else if (_editing)
              CommentComposer(
                initialText: c.body,
                submitLabel: 'Salvar',
                onCancel: () => setState(() => _editing = false),
                onSubmit: (text, _) async {
                  final ok = await widget.onEdit(c, text);
                  if (ok && mounted) setState(() => _editing = false);
                  return ok;
                },
              )
            else
              LinkifiedText(c.body,
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white)),
            if (!c.deleted && !_editing)
              for (final ref in c.refs) RefCard(ref: ref),
            if (!c.deleted && !_editing)
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Curtir',
                    icon: Icon(Icons.thumb_up_alt_outlined,
                        size: 18, color: mine == 1 ? Colors.lightGreenAccent : Colors.white54),
                    onPressed: p.canVote ? () => widget.onVote(c, 1) : null,
                  ),
                  Text('${c.score}', style: const TextStyle(color: Colors.white70)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Não curtir',
                    icon: Icon(Icons.thumb_down_alt_outlined,
                        size: 18, color: mine == -1 ? Colors.redAccent : Colors.white54),
                    onPressed: p.canVote ? () => widget.onVote(c, -1) : null,
                  ),
                  if (p.canReply)
                    TextButton(
                      onPressed: () => widget.onReply(c),
                      child: const Text('Responder'),
                    ),
                  if (p.canEdit)
                    TextButton(
                      onPressed: () => setState(() => _editing = true),
                      child: const Text('Editar'),
                    ),
                  if (p.canDelete)
                    TextButton(
                      onPressed: () => widget.onDelete(c),
                      child: const Text('Apagar'),
                    ),
                ],
              ),
            for (final child in widget.node.children)
              CommentTile(
                node: child,
                perms: widget.perms,
                myVotes: widget.myVotes,
                onVote: widget.onVote,
                onReply: widget.onReply,
                replyingToId: widget.replyingToId,
                onEdit: widget.onEdit,
                onDelete: widget.onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
