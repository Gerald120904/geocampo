import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_controller.dart';
import '../core/auth/auth_state.dart';
import '../core/auth/token_storage.dart';
import '../core/database/local_database.dart';
import '../core/network/api_client.dart';
import '../core/storage/package_import_service.dart';
import '../models/remote_map.dart';
import '../repositories/local_map_repository.dart';
import 'auth_service.dart';
import 'company_service.dart';
import 'map_service.dart';
import 'observation_service.dart';
import 'package_service.dart';
import 'project_share_service.dart';
import 'project_service.dart';

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => const TokenStorage(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(tokenStorageProvider));
});

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  return LocalDatabase();
});

final localMapRepositoryProvider = Provider<LocalMapRepository>((ref) {
  return LocalMapRepository(ref.watch(localDatabaseProvider));
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  );
});

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

final projectServiceProvider = Provider<ProjectService>((ref) {
  return ProjectService(ref.watch(apiClientProvider));
});

final projectListRefreshProvider = NotifierProvider<ProjectListRefresh, int>(
  ProjectListRefresh.new,
);

final projectShareServiceProvider = Provider<ProjectShareService>((ref) {
  return ProjectShareService(ref.watch(apiClientProvider));
});

final companyServiceProvider = Provider<CompanyService>((ref) {
  return CompanyService(ref.watch(apiClientProvider));
});

final mapServiceProvider = Provider<MapService>((ref) {
  return MapService(ref.watch(apiClientProvider));
});

final packageServiceProvider = Provider<PackageService>((ref) {
  return PackageService(
    ref.watch(mapServiceProvider),
    ref.watch(packageImportServiceProvider),
  );
});

final observationServiceProvider = Provider<ObservationService>((ref) {
  return ObservationService(ref.watch(apiClientProvider));
});

final packageImportServiceProvider = Provider<PackageImportService>((ref) {
  return PackageImportService(ref.watch(localMapRepositoryProvider));
});

final pendingProjectMapsProvider =
    NotifierProvider<PendingProjectMaps, Map<String, List<RemoteMap>>>(
      PendingProjectMaps.new,
    );

class PendingProjectMaps extends Notifier<Map<String, List<RemoteMap>>> {
  @override
  Map<String, List<RemoteMap>> build() => const {};

  void add(String projectId, RemoteMap map) {
    final current = state[projectId] ?? const <RemoteMap>[];
    state = {
      ...state,
      projectId: [map, ...current.where((item) => item.id != map.id)],
    };
  }

  void replace(String projectId, List<RemoteMap> maps) {
    final next = Map<String, List<RemoteMap>>.of(state);
    if (maps.isEmpty) {
      next.remove(projectId);
    } else {
      next[projectId] = maps;
    }
    state = next;
  }
}

class ProjectListRefresh extends Notifier<int> {
  @override
  int build() => 0;

  void markChanged() {
    state++;
  }
}
