import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sync_data.dart';
import '../viewmodels/sync_viewmodel.dart';
import 'interventions_list_view.dart';
import 'login_view.dart';

class SyncView extends StatefulWidget {
  const SyncView({super.key});

  @override
  State<SyncView> createState() => _SyncViewState();
}

class _SyncViewState extends State<SyncView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final syncVM = context.read<SyncViewModel>();
      syncVM.addListener(_syncListener);
    });
  }

  @override
  void dispose() {
    // Nota: In un'app reale, fare attenzione all'uso del context nel dispose se è già smontato
    super.dispose();
  }

  void _syncListener() {
    if (!mounted) return;
    final syncVM = context.read<SyncViewModel>();
    
    if (syncVM.syncSuccess) {
      syncVM.resetSyncSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sincronizzazione completata con successo!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const InterventionsListView()),
      );
    }
    
    if (syncVM.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(syncVM.errorMessage!),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () => syncVM.clearError(),
          ),
        ),
      );
      syncVM.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SyncViewModel>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Barra Blu Superiore
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              color: const Color(0xFF4A72B2),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/logo_app.png',
                    height: 32,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.circle, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Tour Isp. v.25',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '(${viewModel.userName})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.exit_to_app, color: Colors.white, size: 28),
                    onPressed: () async {
                      await viewModel.logout();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const LoginView()),
                          (Route<dynamic> route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Column(
                  children: [
                    Text(
                      'Benvenuto ${viewModel.displayName}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Prima di cominciare sincronizza il tuo dispositivo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // Selection Form
                    _buildDropdownRow<Plant>(
                      label: 'Impianto:',
                      value: viewModel.selectedPlant,
                      items: viewModel.plants,
                      onChanged: viewModel.setPlant,
                      hint: 'Seleziona Impianto',
                    ),
                    const SizedBox(height: 12),
                    _buildDropdownRow<SubPlant>(
                      label: 'Sotto-impianto:',
                      value: viewModel.selectedSubPlant,
                      items: viewModel.subPlants,
                      onChanged: viewModel.setSubPlant,
                      hint: 'Seleziona Sotto-Impianti',
                    ),
                    const SizedBox(height: 12),
                    _buildDropdownRow<AppUser>(
                      label: 'Assegnati a:',
                      value: viewModel.selectedUser,
                      items: viewModel.users,
                      onChanged: viewModel.setUser,
                      hint: 'Seleziona Utente',
                    ),
                    const SizedBox(height: 12),
                    _buildDropdownRow<ShiftLeader>(
                      label: 'Capo turno (SDA):',
                      value: viewModel.selectedShiftLeader,
                      items: viewModel.shiftLeaders,
                      onChanged: viewModel.setShiftLeader,
                      hint: '-',
                    ),
                    
                    const SizedBox(height: 60),
                    
                    // Buttons
                    _buildMainButton(
                      text: 'SINCRONIZZA',
                      onPressed: viewModel.isLoading ? null : () => viewModel.synchronize(),
                      isLoading: viewModel.isLoading,
                      color: const Color(0xFF4A72B2),
                    ),
                    const SizedBox(height: 20),
                    _buildMainButton(
                      text: 'RICARICA DATI',
                      onPressed: viewModel.isLoading ? null : () => viewModel.refreshData(),
                      isLoading: false,
                      color: const Color(0xFF4A72B2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownRow<T>({
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String? hint,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade400),
              gradient: LinearGradient(
                colors: [Colors.grey.shade200, Colors.grey.shade400],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
                hint: hint != null ? Text(hint, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)) : null,
                items: items.map((T item) {
                  return DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                      item.toString(),
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainButton({
    required String text,
    required VoidCallback? onPressed,
    required bool isLoading,
    required Color color,
    Color textColor = Colors.white,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: color == Colors.white ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: color == Colors.white || color == Colors.grey.shade100 
                ? BorderSide(color: Colors.grey.shade300) 
                : BorderSide.none,
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: textColor,
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
      ),
    );
  }
}
