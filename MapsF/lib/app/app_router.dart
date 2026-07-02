import 'package:go_router/go_router.dart';

import '../screens/accept_project_share_screen.dart';
import '../screens/change_password_screen.dart';
import '../screens/duplicate_map_review_screen.dart';
import '../screens/enter_share_code_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/login_screen.dart';
import '../screens/map_detail_screen.dart';
import '../screens/map_processing_screen.dart';
import '../screens/map_viewer_screen.dart';
import '../screens/maps_screen.dart';
import '../screens/project_detail_screen.dart';
import '../screens/projects_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/register_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/share_project_screen.dart';
import '../screens/shell_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/upload_map_screen.dart';
import '../screens/verify_email_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/login',
      builder: (context, state) =>
          LoginScreen(redirectPath: state.uri.queryParameters['redirect']),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/verify-email',
      builder: (context, state) =>
          VerifyEmailScreen(email: state.uri.queryParameters['email']),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) =>
          ResetPasswordScreen(email: state.uri.queryParameters['email']),
    ),
    GoRoute(
      path: '/change-password',
      builder: (context, state) => const ChangePasswordScreen(),
    ),
    GoRoute(
      path: '/share/project/:token',
      builder: (context, state) =>
          AcceptProjectShareScreen(token: state.pathParameters['token']!),
    ),
    GoRoute(
      path: '/share/code',
      builder: (context, state) => const EnterShareCodeScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => ShellScreen(child: child),
      routes: [
        GoRoute(
          path: '/projects',
          builder: (context, state) => const ProjectsScreen(),
        ),
        GoRoute(
          path: '/projects/:projectId',
          builder: (context, state) => ProjectDetailScreen(
            projectId: state.pathParameters['projectId']!,
            highlightedMapId: state.uri.queryParameters['highlight_map'],
          ),
        ),
        GoRoute(
          path: '/projects/:projectId/share',
          builder: (context, state) => ShareProjectScreen(
            projectId: state.pathParameters['projectId']!,
            projectName: state.uri.queryParameters['name'],
            readyMapsCount: int.tryParse(
              state.uri.queryParameters['ready_maps'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: '/projects/:projectId/maps',
          builder: (context, state) => MapsScreen(
            projectId: state.pathParameters['projectId']!,
            projectName: state.uri.queryParameters['name'],
          ),
        ),
        GoRoute(
          path: '/upload',
          builder: (context, state) => const UploadMapScreen(),
        ),
        GoRoute(
          path: '/projects/:projectId/upload',
          builder: (context, state) =>
              UploadMapScreen(projectId: state.pathParameters['projectId']!),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/maps/:mapId',
      builder: (context, state) =>
          MapDetailScreen(mapId: state.pathParameters['mapId']!),
    ),
    GoRoute(
      path: '/maps/:mapId/processing',
      builder: (context, state) =>
          MapProcessingScreen(mapId: state.pathParameters['mapId']!),
    ),
    GoRoute(
      path: '/maps/:mapId/duplicate-review',
      builder: (context, state) =>
          DuplicateMapReviewScreen(mapId: state.pathParameters['mapId']!),
    ),
    GoRoute(
      path: '/viewer/:mapId',
      builder: (context, state) =>
          MapViewerScreen.single(mapId: state.pathParameters['mapId']!),
    ),
    GoRoute(
      path: '/maps/:mapId/viewer',
      builder: (context, state) =>
          MapViewerScreen.single(mapId: state.pathParameters['mapId']!),
    ),
    GoRoute(
      path: '/projects/:projectId/viewer',
      builder: (context, state) {
        final rawMapIds = state.uri.queryParameters['map_ids'];
        final mapIds = rawMapIds == null || rawMapIds.trim().isEmpty
            ? const <String>[]
            : rawMapIds.split(',').where((id) => id.trim().isNotEmpty).toList();
        return mapIds.isEmpty
            ? MapViewerScreen.project(
                projectId: state.pathParameters['projectId']!,
              )
            : MapViewerScreen.selection(
                projectId: state.pathParameters['projectId']!,
                mapIds: mapIds,
              );
      },
    ),
  ],
);
