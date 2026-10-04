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

final schoolsListProvider = FutureProvider<List<SchoolSummary>>((ref) {
  return ref.watch(superAdminRepositoryProvider).listSchools();
});

final schoolAdminsProvider = FutureProvider.family<List<SchoolAdminAccount>, String>((ref, schoolId) {
  return ref.watch(superAdminRepositoryProvider).listSchoolAdmins(schoolId);
});

final schoolContentProvider = FutureProvider.family<List<SchoolContentItem>, String>((ref, schoolId) {
  return ref.watch(superAdminRepositoryProvider).listContent(schoolId);
});

final schoolGalleryProvider = FutureProvider.family<List<GalleryItem>, String>((ref, schoolId) {
  return ref.watch(superAdminRepositoryProvider).listGallery(schoolId);
});

final schoolAchievementsProvider = FutureProvider.family<List<AchievementItem>, String>((ref, schoolId) {
  return ref.watch(superAdminRepositoryProvider).listAchievements(schoolId);
});

final schoolEventsProvider = FutureProvider.family<List<EventItem>, String>((ref, schoolId) {
  return ref.watch(superAdminRepositoryProvider).listEvents(schoolId);
});

final schoolAssetsProvider = FutureProvider.family<List<SchoolAssetItem>, String>((ref, schoolId) {
  return ref.watch(superAdminRepositoryProvider).listAssets(schoolId);
});

final academicStructureProvider = FutureProvider.family<AcademicStructure, String>((ref, schoolId) {
  return ref.watch(superAdminRepositoryProvider).getAcademicStructure(schoolId);
});