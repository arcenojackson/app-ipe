enum NotificationType {
  eventReminder('event_reminder', 'Lembretes de eventos próximos', 'Receba lembretes sobre eventos próximos'),
  scaleInclusion('scale_inclusion', 'Inclusão em escalas', 'Seja notificado quando você for incluído em uma escala'),
  eventUpdate('event_update', 'Atualização de eventos', 'Seja notificado quando um evento for atualizado'),
  musicUpdate('music_update', 'Atualização de músicas', 'Seja notificado quando músicas forem adicionadas ou alteradas em eventos'),
  chatMention('chat_mention', 'Menções em chats de eventos', 'Receba notificações quando alguém te mencionar no chat de um evento');

  const NotificationType(this.id, this.title, this.description);

  final String id;
  final String title;
  final String description;

  static NotificationType? fromId(String id) {
    try {
      return NotificationType.values.firstWhere((type) => type.id == id);
    } catch (e) {
      return null;
    }
  }
}
