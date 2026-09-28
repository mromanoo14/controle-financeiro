import 'api_service.dart';

class AuthService {
  final ApiService apiService;

  AuthService(this.apiService);

  Future<String> login(
    String email,
    String senha,
  ) async {
    return apiService.login(
      email,
      senha,
    );
  }

  void logout() {
    apiService.logout();
  }

  bool get autenticado {
    return apiService.token != null;
  }
}