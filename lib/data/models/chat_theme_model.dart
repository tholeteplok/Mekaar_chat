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
  neonCyberpunk,
  comicPopArt,
  neumorphism,
  glassmorphism,
  pixelGarden,
  isometric3d,
  retroY2K,
  swissMinimalist,
  solarpunk,
  fireflyNight,
  diary,
}

/// Model persisten untuk simpan/muat preferensi tema obrolan.
class ChatThemePreference {
  final ChatThemePreset preset;
  final WallpaperType wallpaperType;
  final String? wallpaperValue; // hex color, gradient index, or image path
  final ChatBubbleStyle bubbleStyle;
  final ChatBubbleColorPreset bubbleColorPreset;
  final double textScale;

  const ChatThemePreference({
    this.preset = ChatThemePreset.dynamicTime,
    this.wallpaperType = WallpaperType.dynamicTime,
    this.wallpaperValue,
    this.bubbleStyle = ChatBubbleStyle.modernPill,
    this.bubbleColorPreset = ChatBubbleColorPreset.defaultTime,
    this.textScale = 1.0,
  });

  ChatThemePreference copyWith({
    ChatThemePreset? preset,
    WallpaperType? wallpaperType,
    String? wallpaperValue,
    ChatBubbleStyle? bubbleStyle,
    ChatBubbleColorPreset? bubbleColorPreset,
    double? textScale,
  }) {
    return ChatThemePreference(
      preset: preset ?? this.preset,
      wallpaperType: wallpaperType ?? this.wallpaperType,
      wallpaperValue: wallpaperValue ?? this.wallpaperValue,
      bubbleStyle: bubbleStyle ?? this.bubbleStyle,
      bubbleColorPreset: bubbleColorPreset ?? this.bubbleColorPreset,
      textScale: textScale ?? this.textScale,
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
    };
  }

  factory ChatThemePreference.fromJson(Map<String, dynamic> json) {
    return ChatThemePreference(
      preset: ChatThemePreset.values.firstWhere(
        (e) => e.name == json['preset'],
        orElse: () => ChatThemePreset.dynamicTime,
      ),
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

  /// Preset 2: Neon Cyberpunk.
  static const neonCyberpunk = ChatThemePreference(
    preset: ChatThemePreset.neonCyberpunk,
    wallpaperType: WallpaperType.neonGrid,
    bubbleStyle: ChatBubbleStyle.cyberEdge,
    bubbleColorPreset: ChatBubbleColorPreset.cyberpunkNeon,
    textScale: 1.0,
  );

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

  /// Preset 7: Isometric / 2.5D Tech.
  static const isometric3d = ChatThemePreference(
    preset: ChatThemePreset.isometric3d,
    wallpaperType: WallpaperType.isometricGrid,
    bubbleStyle: ChatBubbleStyle.isometric3D,
    bubbleColorPreset: ChatBubbleColorPreset.isometricBlock,
    textScale: 1.0,
  );

  /// Preset 8: Retro OS / Y2K Aesthetic.
  static const retroY2K = ChatThemePreference(
    preset: ChatThemePreset.retroY2K,
    wallpaperType: WallpaperType.retroY2KCanvas,
    bubbleStyle: ChatBubbleStyle.retroBevel,
    bubbleColorPreset: ChatBubbleColorPreset.retroWin95,
    textScale: 1.0,
  );

  /// Preset 9: Monochrome Minimalist (Swiss Style).
  static const swissMinimalist = ChatThemePreference(
    preset: ChatThemePreset.swissMinimalist,
    wallpaperType: WallpaperType.swissGrid,
    bubbleStyle: ChatBubbleStyle.swissSquare,
    bubbleColorPreset: ChatBubbleColorPreset.swissElectric,
    textScale: 1.0,
  );

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
