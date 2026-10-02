import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_providers.dart';
import 'super_admin_models.dart';
import 'super_admin_repository.dart';

final superAdminRepositoryProvider = Provider<SuperAdminRepository>((ref) {
  return SuperAdminRepository(ref.watch(supabaseClientProvider));
});

final superAdminProfileProvider = FutureProvider<SuperAdminProfile?>((ref) {
  return ref.watch(superAdminRepositoryProvider).getProfile();
});