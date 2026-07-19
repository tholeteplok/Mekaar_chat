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

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String pin = '/pin';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String guardian = '/guardian';
  static const String guardianAdd = '/guardian/add';
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

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case AppRoutes.onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());

      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case AppRoutes.pin:
        final isSetup = settings.arguments as bool? ?? false;
        return MaterialPageRoute(builder: (_) => PinScreen(isSetup: isSetup));

      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const MainNavigationScreen());

      case AppRoutes.chat:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: args['chatId'],
            chatName: args['chatName'],
            chatAvatar: args['chatAvatar'],
            isGuardian: args['isGuardian'] ?? false,
            otherUserId: args['otherUserId'] as String?,
          ),
        );

      case AppRoutes.call:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
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
        return MaterialPageRoute(builder: (_) => const GuardianListScreen());

      case AppRoutes.guardianAdd:
        return MaterialPageRoute(builder: (_) => const AddGuardianScreen());

      case AppRoutes.guardianDetail:
        final g =
            (settings.arguments as Map<String, dynamic>)['guardian']
                as Guardian;
        return MaterialPageRoute(
          builder: (_) => GuardianDetailScreen(guardian: g),
        );

      case AppRoutes.guardianSwap:
        final g =
            (settings.arguments as Map<String, dynamic>)['guardian']
                as Guardian;
        return MaterialPageRoute(
          builder: (_) => SwapGuardianScreen(guardian: g),
        );

      case AppRoutes.guardianTracking:
        return MaterialPageRoute(
          builder: (_) => const GuardianTrackingScreen(),
        );

      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());

      case AppRoutes.duressPin:
        return MaterialPageRoute(builder: (_) => const DuressPinScreen());

      case AppRoutes.logs:
        return MaterialPageRoute(builder: (_) => const SecurityLogsScreen());

      case AppRoutes.profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());

      case AppRoutes.soundPicker:
        return MaterialPageRoute(builder: (_) => const SoundPickerScreen());
      case AppRoutes.blockedList:
        return MaterialPageRoute(builder: (_) => const BlockedListScreen());
      case AppRoutes.twoFactorSetup:
        return MaterialPageRoute(builder: (_) => const TwoFactorSetupScreen());
      case AppRoutes.twoFactor:
        final secret = settings.arguments as String? ?? '';
        return MaterialPageRoute(
            builder: (_) => TwoFactorScreen(twoFaSecret: secret));

      case AppRoutes.sosActive:
        return MaterialPageRoute(builder: (_) => const SOSActiveScreen());

      case AppRoutes.sosVideo:
        return MaterialPageRoute(builder: (_) => const VideoEmergencyScreen());

      case AppRoutes.deviceLost:
        return MaterialPageRoute(builder: (_) => const DeviceLostScreen());

      case AppRoutes.map:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => LocationMapScreen(
            latitude: args['latitude'] as double,
            longitude: args['longitude'] as double,
            locationName: args['locationName'] as String?,
          ),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Route not found: ${settings.name}')),
          ),
        );
    }
  }
}
