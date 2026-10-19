import 'package:flutter/material.dart';

/// Enum tipe ilustrasi terstandarisasi untuk MEKAAR (WebP 512px Optimized).
enum MikaIllustrationType {
  // Empty states (10 Layar)
  emptyArchive('assets/illustrations/il_empty_archive.webp'),
  emptyChat('assets/illustrations/il_empty_chat.webp'),
  emptyContacts('assets/illustrations/il_empty_contacts.webp'),
  emptyGuardian('assets/illustrations/il_empty_guardian.webp'),
  emptyVault('assets/illustrations/il_empty_vault.webp'),
  emptyAutoCheckin('assets/illustrations/il_empty_autocheckin.webp'),
  emptySosHistory('assets/illustrations/il_empty_sos_history.webp'),
  emptyBlocked('assets/illustrations/il_empty_blocked.webp'),
  emptySearch('assets/illustrations/il_empty_search.webp'),
  emptyOffline('assets/illustrations/il_empty_offline.webp'),

  // Onboarding (4 Layar)
  onboardingWelcome('assets/illustrations/il_onboarding_welcome.webp'),
  onboardingGuardian('assets/illustrations/il_onboarding_guardian.webp'),
  onboardingSecurity('assets/illustrations/il_onboarding_security.webp'),
  onboardingSuccess('assets/illustrations/il_onboarding_success.webp');

  final String assetPath;
  const MikaIllustrationType(this.assetPath);
}

/// Spesifikasi konfigurasi legacy per ekspresi Mika (backward-compatibility).
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

  /// Path aset universal (WebP)
  String assetPath({required bool isDark}) =>
      MikaPose.fromIndex(index).illustrationType.assetPath;
}

/// Enum pose/ekspresi maskot Mika untuk kompatibilitas penuh.
/// Setiap pose dipetakan ke aset scene WebP terdekat.
enum MikaPose {
  neutral(MikaPoseSpec(index: 1, semanticDescription: 'Mika tenang'), MikaIllustrationType.emptyChat),
  happy(MikaPoseSpec(index: 3, semanticDescription: 'Mika tersenyum gembira'), MikaIllustrationType.onboardingSuccess),
  hi(MikaPoseSpec(index: 0, semanticDescription: 'Mika melambaikan tangan'), MikaIllustrationType.onboardingWelcome),
  ok(MikaPoseSpec(index: 17, semanticDescription: 'Mika mengacungkan jempol'), MikaIllustrationType.onboardingSuccess),
  love(MikaPoseSpec(index: 2, semanticDescription: 'Mika memberi finger heart cinta'), MikaIllustrationType.onboardingWelcome),
  ask(MikaPoseSpec(index: 9, semanticDescription: 'Mika sedang berpikir'), MikaIllustrationType.emptySearch),
  huft(MikaPoseSpec(index: 24, semanticDescription: 'Mika menghela napas lelah'), MikaIllustrationType.emptyOffline),
  hide(MikaPoseSpec(index: 21, semanticDescription: 'Mika canggung'), MikaIllustrationType.emptyVault),
  phone(MikaPoseSpec(index: 18, semanticDescription: 'Mika memberi isyarat OK'), MikaIllustrationType.emptyContacts),
  shield(MikaPoseSpec(index: 12, semanticDescription: 'Mika siap menjaga'), MikaIllustrationType.emptyGuardian),
  pin(MikaPoseSpec(index: 16, semanticDescription: 'Mika berkacamata keren'), MikaIllustrationType.onboardingSecurity),
  sleep(MikaPoseSpec(index: 7, semanticDescription: 'Mika tertidur lelap'), MikaIllustrationType.emptySosHistory),
  welcome(MikaPoseSpec(index: 20, semanticDescription: 'Mika menyambut hangat'), MikaIllustrationType.onboardingWelcome),
  key(MikaPoseSpec(index: 16, semanticDescription: 'Mika berkacamata hitam'), MikaIllustrationType.emptyVault),

  wave(MikaPoseSpec(index: 0, semanticDescription: 'Mika melambaikan tangan'), MikaIllustrationType.onboardingWelcome),
  fingerHeart(MikaPoseSpec(index: 2, semanticDescription: 'Mika finger heart'), MikaIllustrationType.onboardingWelcome),
  laugh(MikaPoseSpec(index: 3, semanticDescription: 'Mika tertawa lepas'), MikaIllustrationType.onboardingSuccess),
  surprised(MikaPoseSpec(index: 4, semanticDescription: 'Mika terkejut'), MikaIllustrationType.emptySearch),
  alert(MikaPoseSpec(index: 4, semanticDescription: 'Mika waspada'), MikaIllustrationType.emptyGuardian),
  angry(MikaPoseSpec(index: 5, semanticDescription: 'Mika marah'), MikaIllustrationType.emptyBlocked),
  frown(MikaPoseSpec(index: 5, semanticDescription: 'Mika cemberut'), MikaIllustrationType.emptyBlocked),
  shocked(MikaPoseSpec(index: 6, semanticDescription: 'Mika panik dan kaget'), MikaIllustrationType.emptyOffline),
  panic(MikaPoseSpec(index: 6, semanticDescription: 'Mika panik'), MikaIllustrationType.emptyOffline),
  playful(MikaPoseSpec(index: 8, semanticDescription: 'Mika menjulurkan lidah'), MikaIllustrationType.emptyChat),
  tongue(MikaPoseSpec(index: 8, semanticDescription: 'Mika melet'), MikaIllustrationType.emptyChat),
  thinking(MikaPoseSpec(index: 9, semanticDescription: 'Mika berpikir'), MikaIllustrationType.emptySearch),
  sad(MikaPoseSpec(index: 10, semanticDescription: 'Mika sedih'), MikaIllustrationType.emptyOffline),
  crying(MikaPoseSpec(index: 10, semanticDescription: 'Mika menangis'), MikaIllustrationType.emptyOffline),
  bawling(MikaPoseSpec(index: 11, semanticDescription: 'Mika menangis kencang'), MikaIllustrationType.emptyOffline),
  cryingLoud(MikaPoseSpec(index: 11, semanticDescription: 'Mika menangis keras'), MikaIllustrationType.emptyOffline),
  ready(MikaPoseSpec(index: 12, semanticDescription: 'Mika siap sedia'), MikaIllustrationType.emptyGuardian),
  cheer(MikaPoseSpec(index: 12, semanticDescription: 'Mika bersemangat'), MikaIllustrationType.onboardingSuccess),
  pout(MikaPoseSpec(index: 13, semanticDescription: 'Mika menggembungkan pipi'), MikaIllustrationType.emptySearch),
  touched(MikaPoseSpec(index: 14, semanticDescription: 'Mika terharu'), MikaIllustrationType.onboardingWelcome),
  grateful(MikaPoseSpec(index: 14, semanticDescription: 'Mika bersyukur'), MikaIllustrationType.onboardingWelcome),
  celebrate(MikaPoseSpec(index: 15, semanticDescription: 'Mika bersorak'), MikaIllustrationType.onboardingSuccess),
  yay(MikaPoseSpec(index: 15, semanticDescription: 'Mika merayakan gembira'), MikaIllustrationType.onboardingSuccess),
  cool(MikaPoseSpec(index: 16, semanticDescription: 'Mika keren'), MikaIllustrationType.onboardingSecurity),
  thumbsUp(MikaPoseSpec(index: 17, semanticDescription: 'Mika jempol'), MikaIllustrationType.onboardingSuccess),
  handOk(MikaPoseSpec(index: 18, semanticDescription: 'Mika tangan OK'), MikaIllustrationType.emptyContacts),
  party(MikaPoseSpec(index: 19, semanticDescription: 'Mika berpesta'), MikaIllustrationType.onboardingSuccess),
  pray(MikaPoseSpec(index: 20, semanticDescription: 'Mika menangkupkan tangan'), MikaIllustrationType.onboardingWelcome),
  please(MikaPoseSpec(index: 20, semanticDescription: 'Mika memohon'), MikaIllustrationType.onboardingWelcome),
  awkward(MikaPoseSpec(index: 21, semanticDescription: 'Mika berkeringat canggung'), MikaIllustrationType.emptySearch),
  worried(MikaPoseSpec(index: 21, semanticDescription: 'Mika cemas'), MikaIllustrationType.emptyOffline),
  confused(MikaPoseSpec(index: 22, semanticDescription: 'Mika bingung'), MikaIllustrationType.emptySearch),
  question(MikaPoseSpec(index: 22, semanticDescription: 'Mika bertanya-tanya'), MikaIllustrationType.emptySearch),
  heartEyes(MikaPoseSpec(index: 23, semanticDescription: 'Mika mata hati'), MikaIllustrationType.onboardingWelcome),
  sigh(MikaPoseSpec(index: 24, semanticDescription: 'Mika menghela napas'), MikaIllustrationType.emptyOffline);

  const MikaPose(this.spec, this.illustrationType);

  final MikaPoseSpec spec;
  final MikaIllustrationType illustrationType;

  int get poseIndex => spec.index;

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

  String get assetPath => illustrationType.assetPath;
  String resolveAssetPath(BuildContext context, {bool? isDarkOverride}) =>
      illustrationType.assetPath;
}

/// Widget ilustrasi terpusat MEKAAR.
/// Mendukung tipe scene terstandarisasi [MikaIllustrationType] dan kompatibilitas [MikaPose].
class MikaIllustration extends StatelessWidget {
  final MikaIllustrationType type;
  final MikaPose? _pose;
  final double size;
  final Alignment alignment;
  final BoxFit fit;
  final String? semanticLabel;

  const MikaIllustration({
    super.key,
    this.type = MikaIllustrationType.emptyChat,
    MikaPose? pose,
    this.size = 180,
    this.alignment = Alignment.center,
    this.fit = BoxFit.contain,
    this.semanticLabel,
    bool animate = false,
    bool? isDarkOverride,
    Offset? customOffset,
    double? customScale,
  }) : _pose = pose;

  @override
  Widget build(BuildContext context) {
    final effectiveType = _pose != null ? _pose.illustrationType : type;
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        effectiveType.assetPath,
        width: size,
        height: size,
        cacheWidth: 512,
        fit: fit,
        alignment: alignment,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: semanticLabel == null,
        semanticLabel: semanticLabel,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }
}
