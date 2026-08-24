import 'package:flutter/material.dart';
import '../constants/motion.dart';

/// Spesifikasi konfigurasi posisi, skala, alignment, dan semantic per ekspresi Mika.
/// Memungkinkan fine-tuning posisi visual untuk setiap ekspresi maskot secara terpusat.
class MikaPoseSpec {
  final int index;
  final Offset offset;
  final double scale;
  final Alignment alignment;
  final String semanticDescription;

  const MikaPoseSpec({
    required this.index,
    this.offset = Offset.zero,
    this.scale = 1.0,
    this.alignment = Alignment.center,
    required this.semanticDescription,
  });

  /// Path aset dinamis berbasis tema gelap/terang
  String assetPath({required bool isDark}) {
    final folder = isDark ? 'mika_dark' : 'mika_light';
    final fileName = isDark ? 'mika_dark_$index.png' : 'mika_$index.png';
    return 'assets/mascot/$folder/$fileName';
  }
}

/// Enum pose/ekspresi maskot Mika (terdiri dari 25 ekspresi baru adaptif tema).
/// Mempertahankan nama-nama alias lama untuk backward compatibility penuh 100%.
enum MikaPose {
  // ── Backward Compatible / Legacy Aliases ──
  neutral(MikaPoseSpec(index: 1, semanticDescription: 'Mika tenang')),
  happy(MikaPoseSpec(index: 3, semanticDescription: 'Mika tersenyum gembira')),
  hi(MikaPoseSpec(index: 0, semanticDescription: 'Mika melambaikan tangan')),
  ok(MikaPoseSpec(index: 17, semanticDescription: 'Mika mengacungkan jempol')),
  love(MikaPoseSpec(index: 2, semanticDescription: 'Mika memberi finger heart cinta')),
  ask(MikaPoseSpec(index: 9, semanticDescription: 'Mika sedang berpikir')),
  huft(MikaPoseSpec(index: 24, semanticDescription: 'Mika menghela napas lelah')),
  hide(MikaPoseSpec(index: 21, semanticDescription: 'Mika canggung')),
  phone(MikaPoseSpec(index: 18, semanticDescription: 'Mika memberi isyarat OK')),
  shield(MikaPoseSpec(index: 12, semanticDescription: 'Mika siap menjaga')),
  pin(MikaPoseSpec(index: 16, semanticDescription: 'Mika berkacamata keren')),
  sleep(MikaPoseSpec(index: 7, semanticDescription: 'Mika tertidur lelap')),
  welcome(MikaPoseSpec(index: 20, semanticDescription: 'Mika menyambut hangat')),
  key(MikaPoseSpec(index: 16, semanticDescription: 'Mika berkacamata hitam')),

  // ── New Descriptive Named Expressions ──
  wave(MikaPoseSpec(index: 0, semanticDescription: 'Mika melambaikan tangan')),
  fingerHeart(MikaPoseSpec(index: 2, semanticDescription: 'Mika finger heart')),
  laugh(MikaPoseSpec(index: 3, semanticDescription: 'Mika tertawa lepas')),
  surprised(MikaPoseSpec(index: 4, semanticDescription: 'Mika terkejut')),
  alert(MikaPoseSpec(index: 4, semanticDescription: 'Mika waspada')),
  angry(MikaPoseSpec(index: 5, semanticDescription: 'Mika marah')),
  frown(MikaPoseSpec(index: 5, semanticDescription: 'Mika cemberut')),
  shocked(MikaPoseSpec(index: 6, semanticDescription: 'Mika panik dan kaget')),
  panic(MikaPoseSpec(index: 6, semanticDescription: 'Mika panik')),
  playful(MikaPoseSpec(index: 8, semanticDescription: 'Mika menjulurkan lidah')),
  tongue(MikaPoseSpec(index: 8, semanticDescription: 'Mika melet')),
  thinking(MikaPoseSpec(index: 9, semanticDescription: 'Mika berpikir')),
  sad(MikaPoseSpec(index: 10, semanticDescription: 'Mika sedih')),
  crying(MikaPoseSpec(index: 10, semanticDescription: 'Mika menangis')),
  bawling(MikaPoseSpec(index: 11, semanticDescription: 'Mika menangis kencang')),
  cryingLoud(MikaPoseSpec(index: 11, semanticDescription: 'Mika menangis keras')),
  ready(MikaPoseSpec(index: 12, semanticDescription: 'Mika siap sedia')),
  cheer(MikaPoseSpec(index: 12, semanticDescription: 'Mika bersemangat')),
  pout(MikaPoseSpec(index: 13, semanticDescription: 'Mika menggembungkan pipi')),
  touched(MikaPoseSpec(index: 14, semanticDescription: 'Mika terharu')),
  grateful(MikaPoseSpec(index: 14, semanticDescription: 'Mika bersyukur')),
  celebrate(MikaPoseSpec(index: 15, offset: Offset(0, 2), scale: 1.02, semanticDescription: 'Mika bersorak')),
  yay(MikaPoseSpec(index: 15, offset: Offset(0, 2), scale: 1.02, semanticDescription: 'Mika merayakan gembira')),
  cool(MikaPoseSpec(index: 16, semanticDescription: 'Mika keren')),
  thumbsUp(MikaPoseSpec(index: 17, semanticDescription: 'Mika jempol')),
  handOk(MikaPoseSpec(index: 18, semanticDescription: 'Mika tangan OK')),
  party(MikaPoseSpec(index: 19, offset: Offset(0, 2), scale: 1.02, semanticDescription: 'Mika berpesta')),
  pray(MikaPoseSpec(index: 20, semanticDescription: 'Mika menangkupkan tangan')),
  please(MikaPoseSpec(index: 20, semanticDescription: 'Mika memohon')),
  awkward(MikaPoseSpec(index: 21, semanticDescription: 'Mika berkeringat canggung')),
  worried(MikaPoseSpec(index: 21, semanticDescription: 'Mika cemas')),
  confused(MikaPoseSpec(index: 22, semanticDescription: 'Mika bingung')),
  question(MikaPoseSpec(index: 22, semanticDescription: 'Mika bertanya-tanya')),
  heartEyes(MikaPoseSpec(index: 23, semanticDescription: 'Mika mata hati')),
  sigh(MikaPoseSpec(index: 24, semanticDescription: 'Mika menghela napas'));

  const MikaPose(this.spec);

  final MikaPoseSpec spec;

  /// Index file mika_X.png (0 - 24)
  int get poseIndex => spec.index;

  /// Helper untuk mendapatkan pose dari index (0-24)
  static MikaPose fromIndex(int index) {
    return switch (index) {
      0 => MikaPose.wave,
      1 => MikaPose.neutral,
      2 => MikaPose.fingerHeart,
      3 => MikaPose.happy,
      4 => MikaPose.surprised,
      5 => MikaPose.angry,
      6 => MikaPose.shocked,
      7 => MikaPose.sleep,
      8 => MikaPose.playful,
      9 => MikaPose.ask,
      10 => MikaPose.sad,
      11 => MikaPose.bawling,
      12 => MikaPose.ready,
      13 => MikaPose.pout,
      14 => MikaPose.touched,
      15 => MikaPose.celebrate,
      16 => MikaPose.cool,
      17 => MikaPose.thumbsUp,
      18 => MikaPose.handOk,
      19 => MikaPose.party,
      20 => MikaPose.welcome,
      21 => MikaPose.awkward,
      22 => MikaPose.confused,
      23 => MikaPose.heartEyes,
      24 => MikaPose.huft,
      _ => MikaPose.neutral,
    };
  }

  /// Path aset statis default (Light mode) untuk backward compatibility
  String get assetPath => spec.assetPath(isDark: false);

  /// Path aset adaptif tema berbasis BuildContext
  String resolveAssetPath(BuildContext context, {bool? isDarkOverride}) {
    final isDark = isDarkOverride ?? (Theme.of(context).brightness == Brightness.dark);
    return spec.assetPath(isDark: isDark);
  }
}

/// Widget ilustrasi maskot Mika yang otomatis menyesuaikan tema (Light/Dark)
/// dan menerapkan transformasi offset/skala terpusat.
class MikaIllustration extends StatelessWidget {
  const MikaIllustration({
    super.key,
    required this.pose,
    this.size = 120,
    this.alignment = Alignment.center,
    this.fit = BoxFit.contain,
    this.semanticLabel,
    this.animate = false,
    this.isDarkOverride,
    this.customOffset,
    this.customScale,
  });

  final MikaPose pose;
  final double size;
  final Alignment alignment;
  final BoxFit fit;
  final String? semanticLabel;
  final bool animate;
  final bool? isDarkOverride;
  final Offset? customOffset;
  final double? customScale;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final isDark = isDarkOverride ?? (Theme.of(context).brightness == Brightness.dark);
    final spec = pose.spec;
    final finalOffset = customOffset ?? spec.offset;
    final finalScale = customScale ?? spec.scale;

    Widget imageWidget = SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        spec.assetPath(isDark: isDark),
        fit: fit,
        alignment: alignment,
        excludeFromSemantics: semanticLabel == null,
        semanticLabel: semanticLabel ?? spec.semanticDescription,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );

    // Terapkan penyesuaian posisi (offset) dan skala (scale) terpusat
    if (finalOffset != Offset.zero || finalScale != 1.0) {
      imageWidget = Transform.translate(
        offset: finalOffset,
        child: Transform.scale(
          scale: finalScale,
          child: imageWidget,
        ),
      );
    }

    if (!animate || reduceMotion) return imageWidget;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MekaarMotion.slow,
      curve: Curves.easeOutCubic,
      child: imageWidget,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}
