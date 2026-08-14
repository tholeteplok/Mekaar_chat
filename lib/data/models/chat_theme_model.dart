/// Enum tipe wallpaper obrolan.
enum WallpaperType {
  dynamicTime,
  solidColor,
  gradient,
  pattern,
  neonGrid,
  comicHalftone,
  neumorphicCanvas,
  pixelGardenCanvas,
  isometricGrid,
  retroY2KCanvas,
  swissGrid,
  solarpunkCanvas,
  fireflyCanvas,
  diaryRuledPaper,
  customImage,
}

/// Enum gaya kelengkungan & border gelembung obrolan.
enum ChatBubbleStyle {
  modernPill,
  classicRounded,
  compactSharp,
  glassmorphism,
  playfulOutlined,
  cyberEdge,
  neumorphicSoft,
  pixelGardenStyle,
  isometric3D,
  retroBevel,
  swissSquare,
  solarpunkLeaf,
  fireflyAmber,
  diaryHandwriting,
}

/// Enum palet warna gelembubg pengirim & penerima.
enum ChatBubbleColorPreset {
  defaultTime,
  cyberpunkNeon,
  comicPop,
  emeraldTeal,
  purpleDream,
  midnightGold,
  roseGold,
  neumorphicSoft,
  glassmorphismTint,
  pixelGardenNavy,
  isometricBlock,
  retroWin95,
  swissElectric,
  solarpunkSage,
  fireflyAmber,
  diaryInk,
}

/// Enum preset utama obrolan (Total 12 Presets).
enum ChatThemePreset {
  custom,
  dynamicTime,
  neonDreams,
  comicPopArt,
  neumorphism,
  glassmorphism,
  pixelGarden,
  candyPop,
  retroWave,
  monoVibe,
  solarpunk,
  fireflyNight,
  diary,
  // Alias untuk kompatibilitas riwayat preferensi lama
  neonCyberpunk,
  isometric3d,
  retroY2K,
  swissMinimalist,
}

/// Model persisten untuk simpan/muat preferensi tema obrolan.
class ChatThemePreference {
  final ChatThemePreset preset;
  final WallpaperType wallpaperType;
  final String? wallpaperValue; // hex color, gradient index, or image path
  final ChatBubbleStyle bubbleStyle;
  final ChatBubbleColorPreset bubbleColorPreset;
  final double textScale;

  // Custom Bubble Colors (Support 2-Color Gradient for Outgoing & Incoming)
  final bool useCustomBubbleColors;
  final String? outgoingColor1;
  final String? outgoingColor2;
  final String? incomingColor1;
  final String? incomingColor2;

  const ChatThemePreference({
    this.preset = ChatThemePreset.dynamicTime,
    this.wallpaperType = WallpaperType.dynamicTime,
    this.wallpaperValue,
    this.bubbleStyle = ChatBubbleStyle.modernPill,
    this.bubbleColorPreset = ChatBubbleColorPreset.defaultTime,
    this.textScale = 1.0,
    this.useCustomBubbleColors = false,
    this.outgoingColor1,
    this.outgoingColor2,
    this.incomingColor1,
    this.incomingColor2,
  });

  ChatThemePreference copyWith({
    ChatThemePreset? preset,
    WallpaperType? wallpaperType,
    String? wallpaperValue,
    ChatBubbleStyle? bubbleStyle,
    ChatBubbleColorPreset? bubbleColorPreset,
    double? textScale,
    bool? useCustomBubbleColors,
    String? outgoingColor1,
    String? outgoingColor2,
    String? incomingColor1,
    String? incomingColor2,
  }) {
    return ChatThemePreference(
      preset: preset ?? this.preset,
      wallpaperType: wallpaperType ?? this.wallpaperType,
      wallpaperValue: wallpaperValue ?? this.wallpaperValue,
      bubbleStyle: bubbleStyle ?? this.bubbleStyle,
      bubbleColorPreset: bubbleColorPreset ?? this.bubbleColorPreset,
      textScale: textScale ?? this.textScale,
      useCustomBubbleColors:
          useCustomBubbleColors ?? this.useCustomBubbleColors,
      outgoingColor1: outgoingColor1 ?? this.outgoingColor1,
      outgoingColor2: outgoingColor2 ?? this.outgoingColor2,
      incomingColor1: incomingColor1 ?? this.incomingColor1,
      incomingColor2: incomingColor2 ?? this.incomingColor2,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preset': preset.name,
      'wallpaperType': wallpaperType.name,
      'wallpaperValue': wallpaperValue,
      'bubbleStyle': bubbleStyle.name,
      'bubbleColorPreset': bubbleColorPreset.name,
      'textScale': textScale,
      'useCustomBubbleColors': useCustomBubbleColors,
      'outgoingColor1': outgoingColor1,
      'outgoingColor2': outgoingColor2,
      'incomingColor1': incomingColor1,
      'incomingColor2': incomingColor2,
    };
  }

  factory ChatThemePreference.fromJson(Map<String, dynamic> json) {
    final rawPreset = json['preset'] as String?;
    ChatThemePreset p;
    if (rawPreset == 'neonCyberpunk') {
      p = ChatThemePreset.neonDreams;
    } else if (rawPreset == 'isometric3d') {
      p = ChatThemePreset.candyPop;
    } else if (rawPreset == 'retroY2K') {
      p = ChatThemePreset.retroWave;
    } else if (rawPreset == 'swissMinimalist') {
      p = ChatThemePreset.monoVibe;
    } else {
      p = ChatThemePreset.values.firstWhere(
        (e) => e.name == rawPreset,
        orElse: () => ChatThemePreset.dynamicTime,
      );
    }

    return ChatThemePreference(
      preset: p,
      wallpaperType: WallpaperType.values.firstWhere(
        (e) => e.name == json['wallpaperType'],
        orElse: () => WallpaperType.dynamicTime,
      ),
      wallpaperValue: json['wallpaperValue'] as String?,
      bubbleStyle: ChatBubbleStyle.values.firstWhere(
        (e) => e.name == json['bubbleStyle'],
        orElse: () => ChatBubbleStyle.modernPill,
      ),
      bubbleColorPreset: ChatBubbleColorPreset.values.firstWhere(
        (e) => e.name == json['bubbleColorPreset'],
        orElse: () => ChatBubbleColorPreset.defaultTime,
      ),
      textScale: (json['textScale'] as num?)?.toDouble() ?? 1.0,
      useCustomBubbleColors: json['useCustomBubbleColors'] as bool? ?? false,
      outgoingColor1: json['outgoingColor1'] as String?,
      outgoingColor2: json['outgoingColor2'] as String?,
      incomingColor1: json['incomingColor1'] as String?,
      incomingColor2: json['incomingColor2'] as String?,
    );
  }

  /// Preset 1: Dynamic Time (Default).
  static const dynamicTime = ChatThemePreference(
    preset: ChatThemePreset.dynamicTime,
    wallpaperType: WallpaperType.dynamicTime,
    bubbleStyle: ChatBubbleStyle.modernPill,
    bubbleColorPreset: ChatBubbleColorPreset.defaultTime,
    textScale: 1.0,
  );

  /// Preset 2: Neon Dreams (Night Youth).
  static const neonDreams = ChatThemePreference(
    preset: ChatThemePreset.neonDreams,
    wallpaperType: WallpaperType.neonGrid,
    bubbleStyle: ChatBubbleStyle.cyberEdge,
    bubbleColorPreset: ChatBubbleColorPreset.cyberpunkNeon,
    textScale: 1.0,
  );
  static const neonCyberpunk = neonDreams;

  /// Preset 3: Comic Pop Art.
  static const comicPopArt = ChatThemePreference(
    preset: ChatThemePreset.comicPopArt,
    wallpaperType: WallpaperType.comicHalftone,
    bubbleStyle: ChatBubbleStyle.playfulOutlined,
    bubbleColorPreset: ChatBubbleColorPreset.comicPop,
    textScale: 1.0,
  );

  /// Preset 4: Neumorphism / Soft UI.
  static const neumorphism = ChatThemePreference(
    preset: ChatThemePreset.neumorphism,
    wallpaperType: WallpaperType.neumorphicCanvas,
    bubbleStyle: ChatBubbleStyle.neumorphicSoft,
    bubbleColorPreset: ChatBubbleColorPreset.neumorphicSoft,
    textScale: 1.0,
  );

  /// Preset 5: Glassmorphism / Frosted Glass.
  static const glassmorphism = ChatThemePreference(
    preset: ChatThemePreset.glassmorphism,
    wallpaperType: WallpaperType.gradient,
    bubbleStyle: ChatBubbleStyle.glassmorphism,
    bubbleColorPreset: ChatBubbleColorPreset.glassmorphismTint,
    textScale: 1.0,
  );

  /// Preset 6: Pixel Garden 8-Bit (Bluebloom).
  static const pixelGarden = ChatThemePreference(
    preset: ChatThemePreset.pixelGarden,
    wallpaperType: WallpaperType.pixelGardenCanvas,
    bubbleStyle: ChatBubbleStyle.pixelGardenStyle,
    bubbleColorPreset: ChatBubbleColorPreset.pixelGardenNavy,
    textScale: 1.0,
  );

  /// Preset 7: Candy Pop (Playful Youth).
  static const candyPop = ChatThemePreference(
    preset: ChatThemePreset.candyPop,
    wallpaperType: WallpaperType.pattern,
    bubbleStyle: ChatBubbleStyle.modernPill,
    bubbleColorPreset: ChatBubbleColorPreset.roseGold,
    textScale: 1.0,
  );
  static const isometric3d = candyPop;

  /// Preset 8: Retro Wave (Nostalgic Youth).
  static const retroWave = ChatThemePreference(
    preset: ChatThemePreset.retroWave,
    wallpaperType: WallpaperType.retroY2KCanvas,
    bubbleStyle: ChatBubbleStyle.modernPill,
    bubbleColorPreset: ChatBubbleColorPreset.purpleDream,
    textScale: 1.0,
  );
  static const retroY2K = retroWave;

  /// Preset 9: Mono Vibe (Minimalist Youth).
  static const monoVibe = ChatThemePreference(
    preset: ChatThemePreset.monoVibe,
    wallpaperType: WallpaperType.swissGrid,
    bubbleStyle: ChatBubbleStyle.compactSharp,
    bubbleColorPreset: ChatBubbleColorPreset.swissElectric,
    textScale: 1.0,
  );
  static const swissMinimalist = monoVibe;

  /// Preset 10: Solarpunk / Organic Eco-Tech.
  static const solarpunk = ChatThemePreference(
    preset: ChatThemePreset.solarpunk,
    wallpaperType: WallpaperType.solarpunkCanvas,
    bubbleStyle: ChatBubbleStyle.solarpunkLeaf,
    bubbleColorPreset: ChatBubbleColorPreset.solarpunkSage,
    textScale: 1.0,
  );

  /// Preset 11: Kunang-kunang / Firefly Night.
  static const fireflyNight = ChatThemePreference(
    preset: ChatThemePreset.fireflyNight,
    wallpaperType: WallpaperType.fireflyCanvas,
    bubbleStyle: ChatBubbleStyle.fireflyAmber,
    bubbleColorPreset: ChatBubbleColorPreset.fireflyAmber,
    textScale: 1.0,
  );

  /// Preset 12: Buku Harian / Diary.
  static const diary = ChatThemePreference(
    preset: ChatThemePreset.diary,
    wallpaperType: WallpaperType.diaryRuledPaper,
    bubbleStyle: ChatBubbleStyle.diaryHandwriting,
    bubbleColorPreset: ChatBubbleColorPreset.diaryInk,
    textScale: 1.0,
  );
}
