import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart'; // Necessario per IOHttpClientAdapter
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  late Dio _dio;

  factory DioClient() {
    return _instance;
  }

  DioClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl, // Utilizza l'URL definito in AppConfig
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
        headers: {
          'stab': AppConfig.stabHeader, // '2'
          'clientName': AppConfig.clientNameHeader, // 'Mobile'
          'Cache-Control': 'no-cache',
        },
        listFormat: ListFormat.multi, // Parametri ripetuti come key=val1&key=val2 (stile Retrofit)
      ),
    );

    // --- SOLUZIONE ERRORE SSL (CERTIFICATE_VERIFY_FAILED) ---
    // Questo blocco permette di comunicare con server che hanno certificati self-signed
    // NOTA: kIsWeb viene usato per evitare di usare IOHttpClientAdapter su web
    if (!kIsWeb) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
          return client;
        },
      );
    }

    // --- INTERCEPTORS PER TOKEN ---
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Non aggiungiamo il token se stiamo già cercando di ottenerne uno (login)
        if (options.path == 'token') {
          return handler.next(options);
        }

        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');

        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // Log dettagliato degli errori per il debug nel terminale
        String errorMessage = e.message ?? 'Unknown error';
        
        if (kIsWeb && e.response == null) {
          errorMessage = 'ERRORE CORS: Il browser ha bloccato la richiesta. '
              'Assicurati che il server autorizzi le richieste da localhost '
              'o avvia Chrome senza sicurezza (vedi istruzioni).';
        }

        print('DIO ERROR[${e.response?.statusCode}]: $errorMessage');
        
        if (e.response?.statusCode == 401) {
          // Qui potresti gestire il logout automatico
        }
        return handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;

  // Permette di cambiare ambiente (DEV/TEST/PROD) a runtime
  void updateBaseUrl(String newUrl) {
    _dio.options.baseUrl = newUrl;
  }
}