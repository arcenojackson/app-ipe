/// Esquema de cores da arte do calendário.
enum CalendarArtColorScheme {
  light('Claro'),
  dark('Escuro'),
  primary('Tema do app'),
  custom('Personalizado');

  const CalendarArtColorScheme(this.label);
  final String label;

  static CalendarArtColorScheme fromString(String? value) {
    if (value == null) return CalendarArtColorScheme.primary;
    return CalendarArtColorScheme.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CalendarArtColorScheme.primary,
    );
  }
}

/// Tipo de fundo da arte.
enum CalendarArtBackgroundType {
  solid('Cor sólida'),
  gradient2('Gradiente (2 cores)'),
  gradient3('Gradiente (3 cores)');

  const CalendarArtBackgroundType(this.label);
  final String label;

  static CalendarArtBackgroundType fromString(String? value) {
    if (value == null) return CalendarArtBackgroundType.gradient2;
    return CalendarArtBackgroundType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CalendarArtBackgroundType.gradient2,
    );
  }
}

/// Estilo da grade do calendário.
enum CalendarArtCalendarStyle {
  minimal('Minimalista'),
  marked('Marcado (círculos nos dias com evento)'),
  bordered('Com bordas'),
  clean('Sem bordas');

  const CalendarArtCalendarStyle(this.label);
  final String label;

  static CalendarArtCalendarStyle fromString(String? value) {
    if (value == null) return CalendarArtCalendarStyle.marked;
    return CalendarArtCalendarStyle.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CalendarArtCalendarStyle.marked,
    );
  }
}

/// Layout da lista de eventos na arte.
enum CalendarArtEventsLayout {
  listBelow('Abaixo do calendário'),
  listAbove('Acima do calendário');

  const CalendarArtEventsLayout(this.label);
  final String label;

  static CalendarArtEventsLayout fromString(String? value) {
    if (value == null) return CalendarArtEventsLayout.listBelow;
    if (value == 'listAbove') return CalendarArtEventsLayout.listAbove;
    if (value == 'integrated' || value == 'summary') return CalendarArtEventsLayout.listBelow;
    return CalendarArtEventsLayout.listBelow;
  }
}

/// Tamanho de exibição da logo no rodapé da arte (útil quando a imagem por URL fica pequena).
enum LogoDisplaySize {
  small('Pequena', 40),
  medium('Média', 50),
  large('Grande', 60);

  const LogoDisplaySize(this.label, this.height);
  final String label;
  final double height;

  static LogoDisplaySize fromString(String? value) {
    if (value == null) return LogoDisplaySize.medium;
    return LogoDisplaySize.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LogoDisplaySize.medium,
    );
  }
}

/// Cores pré-definidas para o gradiente do fundo da arte.
/// Ao selecionar, o app aplica gradiente de claro para escuro.
const List<int> kCalendarArtGradientColorOptions = [
  0xFF1a237e, // Azul
  0xFF1B5E20, // Verde
  0xFF4A148C, // Roxo
  0xFFB71C1C, // Vermelho
  0xFFE65100, // Laranja
  0xFF004D40, // Teal
  0xFF283593, // Índigo
  0xFF880E4F, // Rosa
  0xFF006064, // Ciano escuro
  0xFFBF360C, // Marrom
  0xFF311B92, // Violeta profundo
  0xFF0D47A1, // Azul profundo
  0xFFAD1457, // Magenta
  0xFF33691E, // Verde escuro
  0xFF4E342E, // Marrom escuro
];

/// Template de customização da arte do calendário (usado na geração e por sociedade).
class CalendarArtTemplate {
  const CalendarArtTemplate({
    this.colorScheme = CalendarArtColorScheme.primary,
    this.backgroundType = CalendarArtBackgroundType.gradient2,
    this.backgroundColors = const [0xFF1a237e, 0xFF0d47a1],
    this.calendarStyle = CalendarArtCalendarStyle.marked,
    this.eventsLayout = CalendarArtEventsLayout.listBelow,
    this.titleText,
    this.gradientColor,
    this.logoImageUrl,
    this.logoDisplaySize = LogoDisplaySize.medium,
  });

  final CalendarArtColorScheme colorScheme;
  final CalendarArtBackgroundType backgroundType;
  final List<int> backgroundColors;
  final CalendarArtCalendarStyle calendarStyle;
  final CalendarArtEventsLayout eventsLayout;
  final String? titleText;
  /// Cor base do gradiente. Quando definida, gera gradiente claro→escuro. Null = padrão (azul).
  final int? gradientColor;
  /// URL da imagem usada no lugar da logo do app no rodapé da arte (ex.: logo da sociedade).
  final String? logoImageUrl;
  /// Tamanho de exibição da logo (útil quando a imagem por URL fica pequena).
  final LogoDisplaySize logoDisplaySize;

  factory CalendarArtTemplate.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const CalendarArtTemplate();
    }
    final colorsRaw = json['backgroundColors'];
    List<int> colors = const [0xFF1a237e, 0xFF0d47a1];
    if (colorsRaw is List) {
      colors = colorsRaw
          .map((e) => e is int ? e : int.tryParse(e.toString(), radix: 16) ?? 0xFF1a237e)
          .toList();
      if (colors.isEmpty) colors = const [0xFF1a237e, 0xFF0d47a1];
    }
    return CalendarArtTemplate(
      colorScheme: CalendarArtColorScheme.fromString(json['colorScheme']?.toString()),
      backgroundType: CalendarArtBackgroundType.fromString(json['backgroundType']?.toString()),
      backgroundColors: colors,
      calendarStyle: CalendarArtCalendarStyle.fromString(json['calendarStyle']?.toString()),
      eventsLayout: CalendarArtEventsLayout.fromString(json['eventsLayout']?.toString()),
      titleText: json['titleText']?.toString(),
      gradientColor: _parseGradientColor(json['gradientColor']),
      logoImageUrl: json['logoImageUrl']?.toString(),
      logoDisplaySize: LogoDisplaySize.fromString(json['logoDisplaySize']?.toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'colorScheme': colorScheme.name,
        'backgroundType': backgroundType.name,
        'backgroundColors': backgroundColors,
        'calendarStyle': calendarStyle.name,
        'eventsLayout': eventsLayout.name,
        if (titleText != null && titleText!.isNotEmpty) 'titleText': titleText,
        if (gradientColor != null) 'gradientColor': gradientColor,
        if (logoImageUrl != null && logoImageUrl!.isNotEmpty) 'logoImageUrl': logoImageUrl,
        'logoDisplaySize': logoDisplaySize.name,
      };

  static int? _parseGradientColor(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value, radix: 16);
    return null;
  }

  CalendarArtTemplate copyWith({
    CalendarArtColorScheme? colorScheme,
    CalendarArtBackgroundType? backgroundType,
    List<int>? backgroundColors,
    CalendarArtCalendarStyle? calendarStyle,
    CalendarArtEventsLayout? eventsLayout,
    String? titleText,
    int? gradientColor,
    String? logoImageUrl,
    LogoDisplaySize? logoDisplaySize,
  }) {
    return CalendarArtTemplate(
      colorScheme: colorScheme ?? this.colorScheme,
      backgroundType: backgroundType ?? this.backgroundType,
      backgroundColors: backgroundColors ?? this.backgroundColors,
      calendarStyle: calendarStyle ?? this.calendarStyle,
      eventsLayout: eventsLayout ?? this.eventsLayout,
      titleText: titleText ?? this.titleText,
      gradientColor: gradientColor ?? this.gradientColor,
      logoImageUrl: logoImageUrl ?? this.logoImageUrl,
      logoDisplaySize: logoDisplaySize ?? this.logoDisplaySize,
    );
  }
}
