import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:campus_lost_found/features/home/presentation/home_page.dart';
import 'package:campus_lost_found/features/found_items/presentation/found_item_details_page.dart';
import 'package:campus_lost_found/features/auth_demo/presentation/settings_page.dart';
import 'package:campus_lost_found/features/auth/presentation/login_page.dart';
import 'package:campus_lost_found/features/auth/presentation/register_page.dart';
import 'package:campus_lost_found/features/chat/presentation/chat_page.dart';

final router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final loggedIn = FirebaseAuth.instance.currentUser != null;
    final loggingIn = state.uri.path == '/login' || state.uri.path == '/register';

    if (!loggedIn && !loggingIn) {
      return '/login';
    }

    if (loggedIn && loggingIn) {
      return '/';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/item/:id',
      builder: (context, state) {
        final itemId = state.pathParameters['id']!;
        return FoundItemDetailsPage(itemId: itemId);
      },
    ),
    GoRoute(
      path: '/item/:id/chat',
      builder: (context, state) {
        final itemId = state.pathParameters['id']!;
        return ChatPage(itemId: itemId);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
  ],
);

