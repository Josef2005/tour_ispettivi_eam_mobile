import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';
import '../core/network/dio_client.dart';

class AuthService {
  // Utilizza l'istanza globale di DioClient
  final Dio _dio = DioClient().dio;

  /*
   * Esegue il login recuperando il token di accesso
   */
  Future<bool> login(String username, String password) async {
    print('AUTH: Tentativo di login online per: $username');
    print('AUTH: URL -> ${_dio.options.baseUrl}token');
    
    try {
      final response = await _dio.post(
        'token',
        data: {
          'username': username,
          'password': password,
          'grant_type': 'password',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Cache-Control': 'no-cache',
            'stab': AppConfig.stabHeader,
            'clientName': AppConfig.clientNameHeader,
          },
        ),
      );

      print('AUTH: Risposta ricevuta status -> ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        final accessToken = data['access_token'];

        if (accessToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', accessToken);
          await prefs.setString('username', username);
          print('AUTH: Login completato con successo.');
          return true;
        }
      }
      print('AUTH: Login fallito (Status code != 200). Dati -> ${response.data}');
      return false;
    } on DioException catch (e) {
      print('AUTH ERROR: DioException!');
      print('AUTH ERROR: Status -> ${e.response?.statusCode}');
      print('AUTH ERROR: Data -> ${e.response?.data}');
      print('AUTH ERROR: Message -> ${e.message}');
      print('AUTH ERROR: Type -> ${e.type}');
      return false;
    } catch (e) {
      print('AUTH ERROR GENERALE: $e');
      return false;
    }
  }

  /*
   * Richiede il reset della password per l'utente specificato
   */
  Future<bool> resetPassword(String username) async {
    try {
      final response = await _dio.put(
        'user/reset-password',
        data: {'username': username},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Errore reset password: $e');
      return false;
    }
  }

  /*
   * Esegue il logout rimuovendo il token di accesso
   */
  Future<bool> logout() async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.remove('access_token');
  }
}