import 'package:dio/dio.dart';

const _defaultBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000/api/v1',
);

class ApiClient {
  ApiClient({String baseUrl = _defaultBaseUrl})
      : dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 10)));

  final Dio dio;
  String? token;

  void setToken(String value) {
    token = value;
    dio.options.headers['Authorization'] = 'Bearer $value';
  }
}
