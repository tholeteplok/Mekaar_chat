import 'package:flutter/material.dart';
import 'package:mekaar_chat/features/auth/screens/login_screen.dart';
import 'package:mekaar_chat/features/auth/screens/onboarding_screen.dart';
import 'package:mekaar_chat/features/auth/screens/pin_screen.dart';
import 'package:mekaar_chat/features/auth/screens/splash_screen.dart';
import 'package:mekaar_chat/features/chat/screens/main_navigation_screen.dart';
import 'package:mekaar_chat/features/chat/screens/chat_screen.dart';
import 'package:mekaar_chat/features/guardian/screens/guardian_list_screen.dart';
import 'package:mekaar_chat/features/guardian/screens/add_guardian_screen.dart';
import 'package:mekaar_chat/features/guardian/screens/guardian_detail_screen.dart';
import 'package:mekaar_chat/features/guardian/screens/swap_guardian_screen.dart';
import 'package:mekaar_chat/features/guardian/screens/guardian_tracking_screen.dart';
import 'package:mekaar_chat/data/models/guardian_model.dart';
import 'package:mekaar_chat/features/settings/screens/settings_screen.dart';
import 'package:mekaar_chat/features/settings/screens/security_logs_screen.dart';
import 'package:mekaar_chat/features/settings/screens/duress_pin_screen.dart';
import 'package:mekaar_chat/features/settings/screens/profile_screen.dart';
import 'package:mekaar_chat/features/settings/screens/sound_picker_screen.dart';
import 'package:mekaar_chat/features/settings/screens/blocked_list_screen.dart';
import 'package:mekaar_chat/features/settings/screens/two_factor_setup_screen.dart';
import 'package:mekaar_chat/features/auth/screens/two_factor_screen.dart';
import 'package:mekaar_chat/features/sos/screens/sos_active_screen.dart';
import 'package:mekaar_chat/features/sos/screens/video_emergency_screen.dart';
import 'package:mekaar_chat/features/sos/screens/device_lost_screen.dart';
import 'package:mekaar_chat/features/map/screens/location_map_screen.dart';
import 'package:mekaar_chat/features/chat/screens/call_screen.dart';
import 'package:mekaar_chat/features/chat/screens/my_qr_screen.dart';
import 'package:mekaar_chat/features/chat/screens/contact_qr_scan_screen.dart';
import 'package:mekaar_chat/features/chat/screens/contact_settings_screen.dart';
import '../constants/motion.dart';

/// MekaarPageRoute — Transisi halaman terpusat.
///
/// Semua navigasi antar layar memakai route ini agar animasi transisi
/// (fade + slide halus 250ms, [MekaarMotion.standard]) selalu konsisten
/// dan menghormati [MediaQuery.disableAnimationsOf].
class MekaarPageRoute extends PageRouteBuilder {
  MekaarPageRoute({required WidgetBuilder builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) {
            FocusManager.instance.primaryFocus?.unfocus();
            return builder(context);
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (MediaQuery.disableAnimationsOf(context)) return child;
            final curved = CurvedAnimation(
              parent: animation,
              curve: MekaarMotion.standard,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
          transitionDuration: MekaarMotion.normal,
        );
}
class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String pin = '/pin';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String guardian = '/guardian';
  static const String guardianAdd = '/guardian/add';
  static const String guardianQrInvite = '/guardian/qr';
  static const String guardianQrScan = '/guardian/qr-scan';
  static const String guardianDetail = '/guardian/detail';
  static const String guardianSwap = '/guardian/swap';
  static const String guardianTracking = '/guardian/tracking';
  static const String settings = '/settings';
  static const String duressPin = '/settings/duress';
  static const String soundPicker = '/settings/sound';
  static const String logs = '/logs';
  static const String profile = '/profile';
  static const String blockedList = '/settings/blocked';
  static const String twoFactorSetup = '/settings/2fa/setup';
  static const String twoFactor = '/auth/2fa';
  static const String sosActive = '/sos/active';
  static const String sosVideo = '/sos/video';
  static const String deviceLost = '/sos/lost';
  static const String map = '/map';
  static const String call = '/call';
  static const String contactQrScan = '/chat/qr-scan';
  static const String myQr = '/chat/my-qr';
  static const String contactSettings = '/chat/settings';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MekaarPageRoute(builder: (_) => const SplashScreen());

      case AppRoutes.onboarding:
        return MekaarPageRoute(builder: (_) => const OnboardingScreen());

      case AppRoutes.login:
        return MekaarPageRoute(builder: (_) => const LoginScreen());

      case AppRoutes.pin:
        final isSetup = settings.arguments as bool? ?? false;
        return MekaarPageRoute(
            builder: (_) => PinScreen(isSetup: isSetup));

      case AppRoutes.home:
        return MekaarPageRoute(
            builder: (_) => const MainNavigationScreen());

      case AppRoutes.chat:
        final args = settings.arguments as Map<String, dynamic>;
        return MekaarPageRoute(
          builder: (_) => ChatScreen(
            chatId: args['chatId'],
            chatName: args['chatName'],
            chatAvatar: args['chatAvatar'],
            chatAvatarUrl: args['chatAvatarUrl'] as String?,
            isGuardian: args['isGuardian'] ?? false,
            otherUserId: args['otherUserId'] as String?,
          ),
        );

      case AppRoutes.call:
        final args = settings.arguments as Map<String, dynamic>;
        return MekaarPageRoute(
          builder: (_) => CallScreen(
            roomId: args['roomId'],
            chatName: args['chatName'],
            callerId: args['callerId'],
            receiverId: args['receiverId'],
            isCaller: args['isCaller'] ?? false,
            callType: args['callType'] ?? 'voice',
          ),
        );

      case AppRoutes.guardian:
        return MekaarPageRoute(
            builder: (_) => const GuardianListScreen());

      case AppRoutes.guardianAdd:
        return MekaarPageRoute(
            builder: (_) => const AddGuardianScreen());

      case AppRoutes.guardianDetail:
        final g =
            (settings.arguments as Map<String, dynamic>)['guardian']
                as Guardian;
        return MekaarPageRoute(
          builder: (_) => GuardianDetailScreen(guardian: g),
        );

      case AppRoutes.guardianSwap:
        final g =
            (settings.arguments as Map<String, dynamic>)['guardian']
                as Guardian;
        return MekaarPageRoute(
          builder: (_) => SwapGuardianScreen(guardian: g),
        );

      case AppRoutes.guardianTracking:
        return MekaarPageRoute(
          builder: (_) => const GuardianTrackingScreen(),
        );

      case AppRoutes.settings:
        return MekaarPageRoute(builder: (_) => const SettingsScreen());

      case AppRoutes.duressPin:
        return MekaarPageRoute(builder: (_) => const DuressPinScreen());

      case AppRoutes.logs:
        return MekaarPageRoute(builder: (_) => const SecurityLogsScreen());

      case AppRoutes.profile:
        return MekaarPageRoute(builder: (_) => const ProfileScreen());

      case AppRoutes.soundPicker:
        return MekaarPageRoute(builder: (_) => const SoundPickerScreen());
      case AppRoutes.blockedList:
        return MekaarPageRoute(builder: (_) => const BlockedListScreen());
      case AppRoutes.twoFactorSetup:
        return MekaarPageRoute(builder: (_) => const TwoFactorSetupScreen());
      case AppRoutes.twoFactor:
        final secret = settings.arguments as String? ?? '';
        return MekaarPageRoute(
            builder: (_) => TwoFactorScreen(twoFaSecret: secret));

      case AppRoutes.sosActive:
        return MekaarPageRoute(builder: (_) => const SOSActiveScreen());

      case AppRoutes.sosVideo:
        return MekaarPageRoute(builder: (_) => const VideoEmergencyScreen());

      case AppRoutes.deviceLost:
        return MekaarPageRoute(builder: (_) => const DeviceLostScreen());

      case AppRoutes.map:
        final args = settings.arguments as Map<String, dynamic>;
        return MekaarPageRoute(
          builder: (_) => LocationMapScreen(
            latitude: args['latitude'] as double,
            longitude: args['longitude'] as double,
            locationName: args['locationName'] as String?,
          ),
        );

      case AppRoutes.contactQrScan:
        return MekaarPageRoute(builder: (_) => const ContactQrScanScreen());

      case AppRoutes.myQr:
        return MekaarPageRoute(builder: (_) => const MyQrScreen());

      case AppRoutes.contactSettings:
        final args = settings.arguments as Map<String, dynamic>;
        return MekaarPageRoute(
          builder: (_) => ContactSettingsScreen(
            roomId: args['roomId'],
            chatName: args['chatName'],
            chatAvatar: args['chatAvatar'],
            otherUserId: args['otherUserId'],
            isGuardian: args['isGuardian'] ?? false,
          ),
        );

      default:
        return MekaarPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Route not found: ${settings.name}')),
          ),
        );
    }
  }
}
