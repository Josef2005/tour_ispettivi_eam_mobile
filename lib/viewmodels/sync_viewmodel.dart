import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sync_data.dart'; // Assuming the models are now named Plant, SubPlant, AppUser, ShiftLeader within this file
import '../services/sync_service.dart';

class SyncViewModel extends ChangeNotifier {
  final SyncService _syncService = SyncService();

  List<Plant> _plants = [];
  List<SubPlant> _subPlants = [];
  List<AppUser> _users = [];
  List<ShiftLeader> _shiftLeaders = [];

  Plant? _selectedPlant;
  SubPlant? _selectedSubPlant;
  AppUser? _selectedUser;
  ShiftLeader? _selectedShiftLeader;

  bool _isLoading = false;
  String? _errorMessage;
  String _userName = '';
  String _displayName = '';
  AppUser? _currentUser;
  List<String> _syncErrors = [];
  List<String> get syncErrors => _syncErrors;

  // Filtra gli impianti in base ai tag di autorizzazione dell'utente
  List<Plant> get plants => _plants.where((p) => _currentUser?.hasAccess(p.authTags) ?? false).toList();
  
  // Filtra i sotto-impianti in base all'impianto selezionato e ai tag dell'utente
  List<SubPlant> get subPlants => _subPlants
      .where((s) =>
          _selectedPlant != null &&
          s.referenceId.contains(_selectedPlant!.id) &&
          (_currentUser?.hasAccess(s.authTags) ?? false))
      .toList();
      
  List<AppUser> get users => _users.where((u) => _currentUser?.hasAccess(u.authTags) ?? false).toList();
  List<ShiftLeader> get shiftLeaders => _shiftLeaders.where((s) => _currentUser?.hasAccess(s.authTags) ?? false).toList();

  Plant? get selectedPlant => _selectedPlant;
  SubPlant? get selectedSubPlant => _selectedSubPlant;
  AppUser? get selectedUser => _selectedUser;
  ShiftLeader? get selectedShiftLeader => _selectedShiftLeader;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get userName => _userName;
  String get displayName => _displayName;

  bool _syncSuccess = false;
  bool get syncSuccess => _syncSuccess;

  SyncViewModel() {
    refreshData();
  }

  /*
   * Pulisce il messaggio di errore
   */
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /*
   * Imposta l'impianto selezionato e aggiorna il sotto-impianto di default se necessario
   */
  Future<void> setPlant(Plant? value) async {
    _selectedPlant = value;
    
    // Pulisce la selezione del sotto-impianto se non appartiene al nuovo impianto
    if (value == null) {
      _selectedSubPlant = null;
    } else {
      final filtered = subPlants;
      if (_selectedSubPlant == null || !filtered.any((s) => s.id == _selectedSubPlant!.id)) {
        _selectedSubPlant = filtered.isNotEmpty ? filtered.first : null;
      }
    }
    
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('IMPIANTO', _selectedPlant?.id ?? '');
    await prefs.setString('SOTTO_IMPIANTO', _selectedSubPlant?.id ?? '');
  }

  /*
   * Imposta il sotto-impianto selezionato
   */
  Future<void> setSubPlant(SubPlant? value) async {
    _selectedSubPlant = value;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('SOTTO_IMPIANTO', value?.id ?? '');
  }

  /*
   * Imposta l'utente (manutentore) selezionato
   */
  Future<void> setUser(AppUser? value) async {
    _selectedUser = value;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('X_ID_MAN_MANUTENTORE', value?.id ?? '');
    // Salviamo anche in USER_ID_SELECTED per riferimento, ma il principale è X_ID_MAN_MANUTENTORE
    await prefs.setString('USER_ID_SELECTED', value?.id ?? '');
  }

  /*
   * Imposta il responsabile selezionato
   */
  Future<void> setShiftLeader(ShiftLeader? value) async {
    _selectedShiftLeader = value;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ResponsabileId', value?.id ?? '');
  }

  Future<void> synchronize() async {
    if (_selectedPlant == null || _selectedSubPlant == null) {
      _errorMessage = 'Selezionare un impianto e un sotto-impianto prima di sincronizzare.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _syncSuccess = false;
    _errorMessage = null;
    _syncErrors = [];
    notifyListeners();

    try {
      _syncErrors = await _syncService.fullSync();
      _syncSuccess = true;
      if (_syncErrors.isNotEmpty) {
        _errorMessage = 'Sincronizzazione completata con alcuni errori.';
      }
    } catch (e) {
      _errorMessage = 'Sincronizzazione fallita: $e';
      _syncSuccess = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  /*
   * Ricarica i metadati dal server e ripristina le selezioni precedenti
   */
  Future<void> refreshData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // Recupera prima le info dell'utente loggato per i tag di autorizzazione
      _currentUser = await _syncService.getCurrentUser();
      if (_currentUser != null) {
        _userName = _currentUser!.username;
        _displayName = _currentUser!.firstName.isNotEmpty ? _currentUser!.firstName : _userName;
        
        // Android Configuration.getUserId uses "USER_ID"
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('USER_ID', _currentUser!.id);
      }

      // Recupera Impianti
      final plantsData = await _syncService.getMetadata('IMPIANTI');
      _plants = plantsData.map((e) => Plant.fromJson(e)).toList();

      // Recupera Sotto-impianti
      final subPlantsData = await _syncService.getMetadata('udvSOTTO_IMPIANTI');
      _subPlants = subPlantsData.map((e) => SubPlant.fromJson(e)).toList();

      // Recupera Manutentori (Utenti)
      final usersData = await _syncService.getMetadata('udvMan_Manutentore_RuoloIspezione'); 
      _users = usersData.map((e) => AppUser.fromJson(e)).toList();

      // Recupera Responsabili (Shift Leaders)
      final shiftLeadersData = await _syncService.getMetadata('udvMan_ManutentoreISPEZIONE_RuoloResponsabile');
      _shiftLeaders = [ShiftLeader(id: '0', name: "-", authTags: _currentUser?.authTags ?? [])] + 
                      shiftLeadersData.map((e) => ShiftLeader.fromJson(e)).toList();

      // Aggiorna le selezioni dalle nuove liste (mantenendo gli ID se possibile)
      final prefs = await SharedPreferences.getInstance();
      final lastPlantId = prefs.getString('IMPIANTO');
      final lastSubPlantId = prefs.getString('SOTTO_IMPIANTO');
      final lastUserId = prefs.getString('X_ID_MAN_MANUTENTORE');
      final lastRespId = prefs.getString('ResponsabileId');

      _selectedPlant = plants.where((i) => i.id == lastPlantId).firstOrNull ??
          (plants.isNotEmpty ? plants.first : null);

      // Filtra e ricarica il sotto-impianto
      final currentSubPlants = subPlants;
      _selectedSubPlant = currentSubPlants.where((s) => s.id == lastSubPlantId).firstOrNull ??
          (currentSubPlants.isNotEmpty ? currentSubPlants.first : null);

      _selectedUser = users.where((u) => u.id == lastUserId).firstOrNull ??
          (users.isNotEmpty ? users.first : null);

      _selectedShiftLeader = shiftLeaders.where((c) => c.id == lastRespId).firstOrNull ??
          (shiftLeaders.isNotEmpty ? shiftLeaders.first : null);

      // Salva i default nelle preferenze per garantire coerenza
      if (_selectedPlant != null) await prefs.setString('IMPIANTO', _selectedPlant!.id);
      if (_selectedSubPlant != null) await prefs.setString('SOTTO_IMPIANTO', _selectedSubPlant!.id);
      if (_selectedUser != null) await prefs.setString('USER_ID', _selectedUser!.id);
      if (_selectedShiftLeader != null) await prefs.setString('ResponsabileId', _selectedShiftLeader!.id);
      
    } catch (e) {
      print('Ricaricamento fallito: $e');
      _errorMessage = 'Caricamento dati fallito: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /*
   * Resetta lo stato di successo della sincronizzazione
   */
  void resetSyncSuccess() {
    _syncSuccess = false;
  }

  /*
   * Esegue il logout rimuovendo il token e pulendo le selezioni
   */
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    // Manteniamo last_username per comodità, ma puliamo i dati di sessione temporanei
    _selectedPlant = null;
    _selectedSubPlant = null;
    _selectedUser = null;
    _selectedShiftLeader = null;
    notifyListeners();
  }
}
