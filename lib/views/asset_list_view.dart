import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inspection.dart';
import '../models/inspection_activity.dart';
import '../viewmodels/asset_viewmodel.dart';
import '../viewmodels/sync_viewmodel.dart';
import '../views/inspection_activity_list_view.dart';

class AssetListView extends StatelessWidget {
  final Inspection inspection;

  const AssetListView({super.key, required this.inspection});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AssetViewModel(inspection: inspection),
      child: const _AssetListContent(),
    );
  }
}

class _AssetListContent extends StatelessWidget {
  const _AssetListContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AssetViewModel>();
    final syncViewModel = context.watch<SyncViewModel>();
    final inspection = viewModel.inspection;

    return Scaffold(
      backgroundColor: const Color(0xFFE8ECEF),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Blue Header
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
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '(${syncViewModel.userName})',
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
                        icon: const Icon(Icons.home, color: Colors.white),
                        onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                      ),
                      IconButton(
                        icon: const Icon(Icons.sync, color: Colors.white),
                        onPressed: () => viewModel.loadActivities(forceSync: true),
                      ),
                      IconButton(
                        icon: const Icon(Icons.exit_to_app, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Inspection Info Bar (Grey)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  color: const Color(0xFFD1D9E6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Color(0xFF4A72B2)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inspection.idext,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'TOUR: ${inspection.getStringDetailValue(Inspection.keyInspectionTour)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Asset List Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Elenco asset',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${viewModel.assetList.length} risultati trovati',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                // List of Assets
                Expanded(
                  child: viewModel.assetList.isEmpty && !viewModel.isLoading
                      ? _buildEmptyState() // Gestione lista vuota (es. Errore 500)
                      : ListView.builder(
                    itemCount: viewModel.assetList.length,
                    itemBuilder: (context, index) {
                      final asset = viewModel.assetList[index];
                      final List activities = asset['activities'] ?? [];

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            (asset['label']?.toString().isNotEmpty == true
                                ? asset['label'].toString()
                                : "ASSET ${asset['id']}").toUpperCase(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A72B2),
                            ),
                          ),
                          // SOTTOTITOLO: Qui vedrai il numero di attività (es. "2 attività")
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              "${activities.length} ${activities.length == 1 ? 'attività' : 'attività'}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildPercentageCircle(asset['percentage'] as int),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InspectionActivityListView(
                                  inspection: viewModel.inspection,
                                  assetId: asset['id'],
                                  assetLabel: asset['label'],
                                  activities: (asset['activities'] as List).cast<InspectionActivity>(),
                                  fullAssetList: viewModel.assetList,
                                ),
                              ),
                            ).then((_) => viewModel.loadActivities());
                          },
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Buttons
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleRelease(context, viewModel),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A72B2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('NON IN CARICO', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleCompletion(context, viewModel),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A72B2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('CONCLUDI ISPEZIONE', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (viewModel.isLoading)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  void _handleRelease(BuildContext context, AssetViewModel viewModel) async {
    await viewModel.releaseInspection();
    if (viewModel.errorMessage != null) {
      _showError(context, viewModel.errorMessage!);
    } else {
      _showSuccess(context, "Intervento rilasciato con successo.", pop: true);
    }
  }

  void _handleCompletion(BuildContext context, AssetViewModel viewModel) async {
    if (viewModel.totalCompletionPercentage < 100) {
      _showError(context, "Completare tutte le attività prima di chiudere.");
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Concludi Ispezione"),
        content: const Text("Sei sicuro di voler concludere l'ispezione?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ANNULLA")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("CONFERMA")),
        ],
      ),
    );

    if (confirmed == true) {
      await viewModel.completeInspection();
      if (viewModel.errorMessage != null) {
        _showError(context, viewModel.errorMessage!);
      } else {
        _showSuccess(context, "Ispezione conclusa con successo.", pop: true);
      }
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(BuildContext context, String message, {bool pop = false}) async {
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Operazione Completata", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF28A745), size: 80),
            const SizedBox(height: 20),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    
    if (context.mounted) {
      Navigator.pop(context); // Close dialog
      if (pop) Navigator.pop(context); // Go back (back to interventions)
    }
  }

  // Widget da mostrare quando non ci sono dati (es. se il sync fallisce)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange.shade300),
          const SizedBox(height: 16),
          const Text(
            "Nessun dato disponibile.",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
          ),
          const Text(
            "Prova a rifare la sincronizzazione.",
            style: TextStyle(color: Colors.black45, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentageCircle(int percentage) {
    if (percentage == 100) {
      return const CircleAvatar(
        radius: 16,
        backgroundColor: Color(0xFF28A745),
        child: Icon(Icons.check, color: Colors.white, size: 20),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            value: percentage / 100,
            strokeWidth: 3,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
          ),
        ),
        Text(
          '$percentage%',
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4A72B2),
          ),
        ),
      ],
    );
  }
}