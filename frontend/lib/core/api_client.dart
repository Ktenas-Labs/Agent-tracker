import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({String baseUrl = 'http://localhost:8000/api/v1'})
      : dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 10)));

  final Dio dio;
  String? token;

  void setToken(String value) {
    token = value;
    dio.options.headers['Authorization'] = 'Bearer $value';
  }
}
