/// Enum tipe wallpaper obrolan (7 Preset Inti + Custom).
enum WallpaperType {
  dynamicTime,
  solidColor,
  comicHalftone,
  neumorphicCanvas,
  gradient,
  pixelGardenCanvas,
  pattern,
  solarpunkCanvas,
  customImage,
  // Alias / Legacy types untuk kompatibilitas riwayat preferensi lama
  neonGrid,
  isometricGrid,
  retroY2KCanvas,
  swissGrid,
  fireflyCanvas,
  diaryRuledPaper,
}

/// Enum gaya kelengkungan & border gelembung obrolan (7 Preset Inti + Utilitas).
enum ChatBubbleStyle {
  modernPill, // Mekaar
  playfulOutlined, // Comic
  neumorphicSoft, // Neuro
  glassmorphism, // Glass
  pixelGardenStyle, // Pixel
  classicRounded, // Candy / Classic
  solarpunkLeaf, // Eco
  // Alias / Legacy styles untuk kompatibilitas riwayat preferensi lama
  compactSharp,
  cyberEdge,
  isometric3D,
  retroBevel,
  swissSquare,
  fireflyAmber,
  diaryHandwriting,
}

/// Enum palet warna gelembung pengirim & penerima.
enum ChatBubbleColorPreset {
  defaultTime,
  comicPop,
  neumorphicSoft,
  glassmorphismTint,
  pixelGardenNavy,
  roseGold,
  solarpunkSage,
  // Alias / Legacy colors
  cyberpunkNeon,
  emeraldTeal,
  purpleDream,
  midnightGold,
  isometricBlock,
  retroWin95,
  swissElectric,
  fireflyAmber,
  diaryInk,
}

/// Enum preset utama obrolan (7 Presets Inti + Custom + Aliases).
enum ChatThemePreset {
  custom,
  mekaar, // 1. Mekaar Clean Theme (Default)
  comic,  // 2. Comic Pop Art
  neuro,  // 3. Neuro / Neumorphism Soft UI
  glass,  // 4. Glassmorphism Frosted Glass
  pixel,  // 5. Pixel Garden 8-Bit
  candy,  // 6. Candy Pop / Playful
  eco,    // 7. Solarpunk Eco Organic Leaf

  // Alias untuk kompatibilitas riwayat preferensi lama
  comicPopArt,
  neumorphism,
  glassmorphism,
  pixelGarden,
  candyPop,
  solarpunk,
  neonDreams,
  retroWave,
  monoVibe,
  fireflyNight,
  diary,
  dynamicTime,
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
    this.preset = ChatThemePreset.mekaar,
    this.wallpaperType = WallpaperType.solidColor,
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
    if (rawPreset == null || rawPreset == 'mekaar' || rawPreset == 'dynamicTime' || rawPreset == 'monoVibe' || rawPreset == 'swissMinimalist') {
      p = ChatThemePreset.mekaar;
    } else if (rawPreset == 'comic' || rawPreset == 'comicPopArt' || rawPreset == 'diary') {
      p = ChatThemePreset.comic;
    } else if (rawPreset == 'neuro' || rawPreset == 'neumorphism' || rawPreset == 'neonDreams' || rawPreset == 'neonCyberpunk') {
      p = ChatThemePreset.neuro;
    } else if (rawPreset == 'glass' || rawPreset == 'glassmorphism' || rawPreset == 'fireflyNight') {
      p = ChatThemePreset.glass;
    } else if (rawPreset == 'pixel' || rawPreset == 'pixelGarden' || rawPreset == 'retroWave' || rawPreset == 'retroY2K') {
      p = ChatThemePreset.pixel;
    } else if (rawPreset == 'candy' || rawPreset == 'candyPop' || rawPreset == 'isometric3d') {
      p = ChatThemePreset.candy;
    } else if (rawPreset == 'eco' || rawPreset == 'solarpunk') {
      p = ChatThemePreset.eco;
    } else if (rawPreset == 'custom') {
      p = ChatThemePreset.custom;
    } else {
      p = ChatThemePreset.values.firstWhere(
        (e) => e.name == rawPreset,
        orElse: () => ChatThemePreset.mekaar,
      );
    }

    return ChatThemePreference(
      preset: p,
      wallpaperType: WallpaperType.values.firstWhere(
        (e) => e.name == json['wallpaperType'],
        orElse: () => WallpaperType.solidColor,
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

  /// Preset 1: MEKAAR Clean Theme (Default).
  static const mekaar = ChatThemePreference(
    preset: ChatThemePreset.mekaar,
    wallpaperType: WallpaperType.solidColor,
    bubbleStyle: ChatBubbleStyle.modernPill,
    bubbleColorPreset: ChatBubbleColorPreset.defaultTime,
    textScale: 1.0,
  );
  static const dynamicTime = mekaar;

  /// Preset 2: Comic Pop Art.
  static const comic = ChatThemePreference(
    preset: ChatThemePreset.comic,
    wallpaperType: WallpaperType.comicHalftone,
    bubbleStyle: ChatBubbleStyle.playfulOutlined,
    bubbleColorPreset: ChatBubbleColorPreset.comicPop,
    textScale: 1.0,
  );
  static const comicPopArt = comic;

  /// Preset 3: Neuro / Neumorphism Soft UI.
  static const neuro = ChatThemePreference(
    preset: ChatThemePreset.neuro,
    wallpaperType: WallpaperType.neumorphicCanvas,
    bubbleStyle: ChatBubbleStyle.neumorphicSoft,
    bubbleColorPreset: ChatBubbleColorPreset.neumorphicSoft,
    textScale: 1.0,
  );
  static const neumorphism = neuro;

  /// Preset 4: Glassmorphism / Frosted Glass.
  static const glass = ChatThemePreference(
    preset: ChatThemePreset.glass,
    wallpaperType: WallpaperType.gradient,
    bubbleStyle: ChatBubbleStyle.glassmorphism,
    bubbleColorPreset: ChatBubbleColorPreset.glassmorphismTint,
    textScale: 1.0,
  );
  static const glassmorphism = glass;

  /// Preset 5: Pixel Garden 8-Bit (Arcade).
  static const pixel = ChatThemePreference(
    preset: ChatThemePreset.pixel,
    wallpaperType: WallpaperType.pixelGardenCanvas,
    bubbleStyle: ChatBubbleStyle.pixelGardenStyle,
    bubbleColorPreset: ChatBubbleColorPreset.pixelGardenNavy,
    textScale: 1.0,
  );
  static const pixelGarden = pixel;

  /// Preset 6: Candy Pop (Playful).
  static const candy = ChatThemePreference(
    preset: ChatThemePreset.candy,
    wallpaperType: WallpaperType.pattern,
    bubbleStyle: ChatBubbleStyle.classicRounded,
    bubbleColorPreset: ChatBubbleColorPreset.roseGold,
    textScale: 1.0,
  );
  static const candyPop = candy;
  static const isometric3d = candy;

  /// Preset 7: Eco / Solarpunk (Organic Leaf).
  static const eco = ChatThemePreference(
    preset: ChatThemePreset.eco,
    wallpaperType: WallpaperType.solarpunkCanvas,
    bubbleStyle: ChatBubbleStyle.solarpunkLeaf,
    bubbleColorPreset: ChatBubbleColorPreset.solarpunkSage,
    textScale: 1.0,
  );
  static const solarpunk = eco;

  // Legacy Presets Aliases
  static const neonDreams = neuro;
  static const neonCyberpunk = neuro;
  static const retroWave = pixel;
  static const retroY2K = pixel;
  static const monoVibe = mekaar;
  static const swissMinimalist = mekaar;
  static const fireflyNight = glass;
  static const diary = comic;
}
