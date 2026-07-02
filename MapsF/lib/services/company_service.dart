import '../core/network/api_client.dart';
import '../models/company.dart';

class CompanyService {
  CompanyService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Company>> listCompanies() async {
    try {
      final response = await _apiClient.dio.get('/companies');
      final list = response.data as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(Company.fromJson)
          .toList();
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<Company> createCompany({
    required String name,
    required String identifier,
    String? legalName,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/companies',
        data: {'name': name, 'legal_name': legalName, 'identifier': identifier},
      );
      return Company.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }
}
