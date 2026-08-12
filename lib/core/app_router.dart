import 'package:go_router/go_router.dart';

import '../features/landing/landing_page.dart';
import '../features/auth/sign_in_page.dart';
import '../features/auth/sign_up_page.dart';
import '../features/auth/parent_sign_up_page.dart';
import '../features/auth/teacher_sign_up_page.dart';
import '../features/auth/auth_gate.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', name: 'landing', builder: (context, state) => const LandingPage()),
    GoRoute(path: '/sign-in', name: 'sign-in', builder: (context, state) => const SignInPage()),
    GoRoute(path: '/sign-up', name: 'sign-up', builder: (context, state) => const SignUpPage()),
    GoRoute(
      path: '/sign-up/parent',
      name: 'sign-up-parent',
      builder: (context, state) => const ParentSignUpPage(),
    ),
    GoRoute(
      path: '/sign-up/teacher',
      name: 'sign-up-teacher',
      builder: (context, state) => const TeacherSignUpPage(),
    ),
    // One login form determines the role - these routes are the
    // POST-sign-in destinations, never chosen by the user directly.
    // Each is a placeholder until that role's real dashboard is built.
    GoRoute(
      path: '/parent',
      builder: (context, state) => const RoleGate(requiredRole: 'parent', label: 'Parent'),
    ),
    GoRoute(
      path: '/teacher',
      builder: (context, state) => const RoleGate(requiredRole: 'teacher', label: 'Teacher'),
    ),
    GoRoute(
      path: '/principal',
      builder: (context, state) => const RoleGate(requiredRole: 'principal', label: 'Principal'),
    ),
    GoRoute(
      path: '/secretary',
      builder: (context, state) => const RoleGate(requiredRole: 'secretary', label: 'Secretary'),
    ),
    GoRoute(
      path: '/proprietor',
      builder: (context, state) => const RoleGate(requiredRole: 'proprietor', label: 'Proprietor'),
    ),
  ],
);