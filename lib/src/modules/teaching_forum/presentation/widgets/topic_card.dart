import 'package:flutter/material.dart';

import '../../../../shared/widgets/glass_container.dart';
import '../../models/forum_models.dart';
import 'forum_scaffold.dart';

class TopicCard extends StatelessWidget {
  const TopicCard({
    super.key,
    required this.topic,
    required this.tagNames,
    required this.onTap,
  });

  final ForumTopic topic;
  final Map<String, String> tagNames;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjects = topic.tagIds.map((id) => tagNames[id]).whereType<String>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (topic.pinned)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.push_pin, size: 16, color: Colors.amber),
                    ),
                  if (topic.locked)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.lock, size: 16, color: Colors.white54),
                    ),
                  Expanded(
                    child: Text(
                      topic.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${topic.authorName} · ${forumDate(topic.lastActivityAt)}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 14, color: Colors.white54),
                  const SizedBox(width: 4),
                  Text('${topic.commentCount}',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      subjects.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
