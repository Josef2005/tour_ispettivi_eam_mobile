import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;
  String _lastUsername = '';

  bool get isLoading => _isLoading;
  bool get isPasswordVisible => _isPasswordVisible;
  String? get errorMessage => _errorMessage;
  String get lastUsername => _lastUsername;

  LoginViewModel() {
    _loadLastUsername();
  }

  /*
   * Carica l'ultimo username salvato dalle preferenze
   */
  Future<void> _loadLastUsername() async {
    final prefs = await SharedPreferences.getInstance();
    _lastUsername = prefs.getString('last_username') ?? '';
    notifyListeners();
  }

  /*
   * Alterna la visibilità della password
   */
  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  /*
   * Esegue il login (online o offline)
   */
  Future<bool> login(String username, String password) async {
    if (username.isEmpty || password.isEmpty) {
      _errorMessage = "Inserire username e password";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Tentativo di login online
      final success = await _authService.login(username, password);
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_username', username);
        // Nota: In produzione sarebbe meglio usare una memoria sicura (secure storage)
        await prefs.setString('last_password', password); 
        _lastUsername = username;
        return true;
      }
      _errorMessage = "Credenziali non valide";
      return false;
    } catch (e) {
      if (kIsWeb) {
        _errorMessage = "Errore di connessione o CORS. Se sei su Chrome, prova ad avviarlo senza sicurezza.";
      } else {
        // Tentativo di login offline in caso di errore di connessione
        final prefs = await SharedPreferences.getInstance();
        final lastUser = prefs.getString('last_username');
        final lastPass = prefs.getString('last_password');
        
        if (username == lastUser && password == lastPass) {
          _lastUsername = username;
          _errorMessage = "Modalità Offline: Accesso consentito";
          notifyListeners();
          return true;
        }
        
        _errorMessage = "Impossibile connettersi al server e credenziali offline non trovate";
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /*
   * Richiede il reset della password
   */
  Future<bool> resetPassword(String username) async {
    if (username.isEmpty) {
      _errorMessage = "Inserire uno username";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _authService.resetPassword(username);
      if (!success) {
        _errorMessage = "Errore durante la richiesta di reset password";
      }
      return success;
    } catch (e) {
      _errorMessage = "Errore di connessione";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
