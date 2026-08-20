import 'package:flutter/material.dart';
import 'package:mekaar_chat/features/auth/screens/forgot_password_screen.dart';
import 'package:mekaar_chat/features/auth/screens/new_password_screen.dart';
import 'package:mekaar_chat/features/auth/screens/set_username_screen.dart';
import 'package:mekaar_chat/features/auth/screens/login_screen.dart';
import 'package:mekaar_chat/features/auth/screens/onboarding_screen.dart';
import 'package:mekaar_chat/features/auth/screens/pin_screen.dart';
import 'package:mekaar_chat/features/auth/screens/splash_screen.dart';
import 'package:mekaar_chat/features/auth/screens/account_suspended_screen.dart';
import 'package:mekaar_chat/features/chat/screens/main_navigation_screen.dart';
import 'package:mekaar_chat/features/chat/screens/chat_screen.dart';
import 'package:mekaar_chat/features/chat/screens/chat_requests_screen.dart';
import 'package:mekaar_chat/features/guardian/screens/guardian_list_screen.dart';
import 'package:mekaar_chat/features/guardian/screens/add_guardian_screen.dart';
import 'package:mekaar_chat/features/guardian/screens/guardian_detail_screen.dart';
import 'package:mekaar_chat/features/guardian/screens/swap_guardian_screen.dart';
import 'package:mekaar_chat/features/guardian/screens/guardian_tracking_screen.dart';
import 'package:mekaar_chat/features/guardian/screens/qr_invite_screen.dart';
import 'package:mekaar_chat/features/guardian/screens/qr_scan_screen.dart';
import 'package:mekaar_chat/data/models/guardian_model.dart';
import 'package:mekaar_chat/features/settings/screens/settings_screen.dart';
import 'package:mekaar_chat/features/settings/screens/theme_settings_screen.dart';
import 'package:mekaar_chat/features/settings/screens/chat_theme_settings_screen.dart';
import 'package:mekaar_chat/features/settings/screens/security_logs_screen.dart';
import 'package:mekaar_chat/features/settings/screens/duress_pin_screen.dart';
import 'package:mekaar_chat/features/settings/screens/profile_screen.dart';
import 'package:mekaar_chat/features/settings/screens/sound_picker_screen.dart';
import 'package:mekaar_chat/features/settings/screens/blocked_list_screen.dart';
import 'package:mekaar_chat/features/settings/screens/two_factor_setup_screen.dart';
import 'package:mekaar_chat/features/settings/screens/trip_list_screen.dart';
import 'package:mekaar_chat/features/settings/screens/add_trip_screen.dart';
import 'package:mekaar_chat/features/settings/screens/trip_arrival_confirm_screen.dart';
import 'package:mekaar_chat/features/settings/screens/about_mekaar_screen.dart';
import 'package:mekaar_chat/features/map/screens/location_picker_screen.dart';
import 'package:mekaar_chat/features/auth/screens/two_factor_screen.dart';
import 'package:mekaar_chat/features/sos/screens/sos_active_screen.dart';
import 'package:mekaar_chat/features/sos/screens/video_emergency_screen.dart';
import 'package:mekaar_chat/features/sos/screens/device_lost_screen.dart';
import 'package:mekaar_chat/features/sos/screens/device_lost_lock_screen.dart';
import 'package:mekaar_chat/features/map/screens/location_map_screen.dart';
import 'package:mekaar_chat/features/chat/screens/call_screen.dart';
import 'package:mekaar_chat/features/chat/screens/my_qr_screen.dart';
import 'package:mekaar_chat/features/chat/screens/contact_qr_scan_screen.dart';
import 'package:mekaar_chat/features/chat/screens/contact_settings_screen.dart';
import 'package:mekaar_chat/features/chat/screens/create_group_select_members_screen.dart';
import 'package:mekaar_chat/features/chat/screens/create_group_details_screen.dart';
import 'package:mekaar_chat/features/chat/screens/group_details_screen.dart';
import '../constants/motion.dart';

/// MekaarPageRoute — Transisi halaman terpusat.
///
/// Semua navigasi antar layar memakai route ini agar animasi transisi
/// (fade + slide + scale, [MekaarMotion.bounce]) selalu konsisten
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
              curve: MekaarMotion.bounce,
            );
            final reverse = CurvedAnimation(
              parent: animation,
              curve: MekaarMotion.standard,
              reverseCurve: MekaarMotion.standard,
            );
            return AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final isForward = animation.status == AnimationStatus.forward;
                final t = isForward ? curved.value : reverse.value;
                return Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - t)),
                    child: Transform.scale(
                      scale: 0.96 + 0.04 * t,
                      child: child,
                    ),
                  ),
                );
              },
              child: child,
            );
          },
          transitionDuration: MekaarMotion.normal,
          reverseTransitionDuration: MekaarMotion.fast,
        );
}
class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String setUsername = '/set-username';
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
  static const String themeSettings = '/settings/theme';
  static const String chatThemeSettings = '/settings/theme/chat';
  static const String duressPin = '/settings/duress';
  static const String soundPicker = '/settings/sound';
  static const String logs = '/logs';
  static const String profile = '/profile';
  static const String blockedList = '/settings/blocked';
  static const String tripList = '/settings/trips';
  static const String addTrip = '/settings/trips/add';
  static const String tripArrivalConfirm = '/settings/trips/confirm';
  static const String twoFactorSetup = '/settings/2fa/setup';
  static const String twoFactor = '/auth/2fa';
  static const String forgotPassword = '/auth/forgot-password';
  static const String newPassword = '/auth/new-password';
  static const String sosActive = '/sos/active';
  static const String sosVideo = '/sos/video';
  static const String deviceLost = '/sos/lost';
  static const String deviceLostLock = '/sos/lost/lock';
  static const String map = '/map';
  static const String mapPicker = '/map/picker';
  static const String call = '/call';
  static const String contactQrScan = '/chat/qr-scan';
  static const String myQr = '/chat/my-qr';
  static const String contactSettings = '/chat/settings';
  static const String createGroupSelectMembers = '/chat/group/select-members';
  static const String createGroupDetails = '/chat/group/details';
  static const String groupDetails = '/chat/group/info';
  static const String accountSuspended = '/auth/account-suspended';
  static const String chatRequests = '/chat/requests';
  static const String about = '/settings/about';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.chatRequests:
        return MekaarPageRoute(builder: (_) => const ChatRequestsScreen());
      case AppRoutes.accountSuspended:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MekaarPageRoute(
          builder: (_) => AccountSuspendedScreen(
            reason: args['reason'] as String?,
            suspendedAt: args['suspendedAt'] as String?,
          ),
        );
      case AppRoutes.splash:
        return MekaarPageRoute(builder: (_) => const SplashScreen());

      case AppRoutes.onboarding:
        return MekaarPageRoute(builder: (_) => const OnboardingScreen());

      case AppRoutes.login:
        return MekaarPageRoute(builder: (_) => const LoginScreen());

      case AppRoutes.setUsername:
        return MekaarPageRoute(builder: (_) => const SetUsernameScreen());

      case AppRoutes.pin:
        final isSetup = settings.arguments as bool? ?? false;
        return MekaarPageRoute(
            builder: (_) => PinScreen(isSetup: isSetup));

      case AppRoutes.home:
        return MekaarPageRoute(
            builder: (_) => const MainNavigationScreen());

      case AppRoutes.chat:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
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
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MekaarPageRoute(
          builder: (_) => CallScreen(
            callId: args['callId'] as String?,
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

      case AppRoutes.guardianQrInvite:
        return MekaarPageRoute(
            builder: (_) => const QrInviteScreen());

      case AppRoutes.guardianQrScan:
        return MekaarPageRoute(
            builder: (_) => const QrScanScreen());

      case AppRoutes.guardianDetail:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final g = args['guardian'] as Guardian;
        return MekaarPageRoute(
          builder: (_) => GuardianDetailScreen(guardian: g),
        );

      case AppRoutes.guardianSwap:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final g = args['guardian'] as Guardian;
        return MekaarPageRoute(
          builder: (_) => SwapGuardianScreen(guardian: g),
        );

      case AppRoutes.guardianTracking:
        return MekaarPageRoute(
          builder: (_) => const GuardianTrackingScreen(),
        );

      case AppRoutes.settings:
        return MekaarPageRoute(builder: (_) => const SettingsScreen());

      case AppRoutes.themeSettings:
        return MekaarPageRoute(builder: (_) => const ThemeSettingsScreen());

      case AppRoutes.chatThemeSettings:
        return MekaarPageRoute(builder: (_) => const ChatThemeSettingsScreen());

      case AppRoutes.duressPin:
        return MekaarPageRoute(builder: (_) => const DuressPinScreen());

      case AppRoutes.logs:
        return MekaarPageRoute(builder: (_) => const SecurityLogsScreen());

      case AppRoutes.profile:
        return MekaarPageRoute(builder: (_) => const ProfileScreen());

      case AppRoutes.soundPicker:
        return MekaarPageRoute(builder: (_) => const SoundPickerScreen());
      case AppRoutes.about:
        return MekaarPageRoute(builder: (_) => const AboutMekaarScreen());
      case AppRoutes.blockedList:
        return MekaarPageRoute(builder: (_) => const BlockedListScreen());
      case AppRoutes.tripList:
        return MekaarPageRoute(builder: (_) => const TripListScreen());
      case AppRoutes.addTrip:
        return MekaarPageRoute(builder: (_) => const AddTripScreen());
      case AppRoutes.tripArrivalConfirm:
        final tripId = (settings.arguments as Map<String, dynamic>?)?['tripId'] as String? ?? '';
        return MekaarPageRoute(
          builder: (_) => TripArrivalConfirmScreen(tripId: tripId),
        );
      case AppRoutes.mapPicker:
        final radius = settings.arguments as int? ?? 150;
        return MekaarPageRoute(
          builder: (_) => LocationPickerScreen(radiusMeters: radius),
        );
      case AppRoutes.twoFactorSetup:
        return MekaarPageRoute(builder: (_) => const TwoFactorSetupScreen());
      case AppRoutes.twoFactor:
        final secret = settings.arguments as String? ?? '';
        return MekaarPageRoute(
            builder: (_) => TwoFactorScreen(twoFaSecret: secret));

      case AppRoutes.forgotPassword:
        return MekaarPageRoute(builder: (_) => const ForgotPasswordScreen());

      case AppRoutes.newPassword:
        return MekaarPageRoute(builder: (_) => const NewPasswordScreen());

      case AppRoutes.sosActive:
        return MekaarPageRoute(builder: (_) => const SOSActiveScreen());

      case AppRoutes.sosVideo:
        return MekaarPageRoute(builder: (_) => const VideoEmergencyScreen());

      case AppRoutes.deviceLost:
        return MekaarPageRoute(builder: (_) => const DeviceLostScreen());

      case AppRoutes.deviceLostLock:
        return MekaarPageRoute(builder: (_) => const DeviceLostLockScreen());

      case AppRoutes.map:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MekaarPageRoute(
          builder: (_) => LocationMapScreen(
            latitude: args['latitude'] as double,
            longitude: args['longitude'] as double,
            locationName: args['locationName'] as String?,
          ),
        );

      case AppRoutes.contactSettings:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MekaarPageRoute(
          builder: (_) => ContactSettingsScreen(
            roomId: args['roomId'],
            chatName: args['chatName'],
            chatAvatar: args['chatAvatar'],
            otherUserId: args['otherUserId'],
            isGuardian: args['isGuardian'] ?? false,
          ),
        );

      case AppRoutes.createGroupSelectMembers:
        return MekaarPageRoute(
            builder: (_) => const CreateGroupSelectMembersScreen());

      case AppRoutes.createGroupDetails:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final ids = (args['selectedUserIds'] as List?)?.cast<String>() ?? [];
        final profiles = (args['selectedUserProfiles'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        return MekaarPageRoute(
          builder: (_) => CreateGroupDetailsScreen(
            selectedUserIds: ids,
            selectedUserProfiles: profiles,
          ),
        );

      case AppRoutes.groupDetails:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final roomId = args['roomId'] as String? ?? '';
        final name = args['groupName'] as String? ?? 'Detail Grup';
        final avatarUrl = args['groupAvatarUrl'] as String?;
        return MekaarPageRoute(
          builder: (_) => GroupDetailsScreen(
            roomId: roomId,
            groupName: name,
            groupAvatarUrl: avatarUrl,
          ),
        );

      case AppRoutes.contactQrScan:
        return MekaarPageRoute(builder: (_) => const ContactQrScanScreen());

      case AppRoutes.myQr:
        return MekaarPageRoute(builder: (_) => const MyQrScreen());

      default:
        return MekaarPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Route not found: ${settings.name}')),
          ),
        );
    }
  }
}
