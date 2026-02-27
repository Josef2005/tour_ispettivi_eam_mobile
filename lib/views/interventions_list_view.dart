import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/interventions_viewmodel.dart';
import '../viewmodels/sync_viewmodel.dart';
import '../models/inspection.dart';
import 'login_view.dart';
import 'asset_list_view.dart';

class InterventionsListView extends StatefulWidget {
  const InterventionsListView({super.key});

  @override
  State<InterventionsListView> createState() => _InterventionsListViewState();
}

class _InterventionsListViewState extends State<InterventionsListView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InterventionsViewModel>().loadInterventions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<InterventionsViewModel>();
    final syncViewModel = context.watch<SyncViewModel>();

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
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.sync, color: Colors.white),
                    onPressed: () => viewModel.loadInterventions(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.exit_to_app, color: Colors.white, size: 28),
                    onPressed: () async {
                      await syncViewModel.logout();
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

            // Barra di ricerca/filtro
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ELENCO INTERVENTI',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A72B2),
                    ),
                  ),
                  Text(
                    '${viewModel.interventions.length} risultati trovati',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

            // Lista Interventi
            Expanded(
              child: viewModel.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : viewModel.interventions.isEmpty
                      ? const Center(
                          child: Text(
                            "Nessun intervento trovato",
                            style: TextStyle(color: Colors.black38, fontSize: 16),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          itemCount: viewModel.interventions.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, indent: 20, endIndent: 20),
                          itemBuilder: (context, index) {
                            final item = viewModel.interventions[index];
                            return _buildInterventionItem(context, item, viewModel);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterventionItem(BuildContext context, Inspection item, InterventionsViewModel viewModel) {
    final tour = item.getStringDetailValue(Inspection.keyInspectionTour);
    final date = item.getStringDetailValue(Inspection.keyPlannedDate);
    final plant = item.getStringDetailValueLabel(Inspection.keyPlant);
    final subPlant = item.getStringDetailValueLabel(Inspection.keySubPlant);
    final percentage = viewModel.getCompletionPercentage(item.idext);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AssetListView(inspection: item),
          ),
        ).then((_) => viewModel.loadInterventions());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tour,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Code: ${item.code} • $date',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.black38),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$plant ($subPlant)',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black45,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _buildPercentageCircle(percentage),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _buildPercentageCircle(int percentage) {
    if (percentage < 0) return const SizedBox.shrink();

    if (percentage == 100) {
      return const CircleAvatar(
        radius: 20,
        backgroundColor: Color(0xFF28A745),
        child: Icon(Icons.check, color: Colors.white, size: 24),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            value: percentage / 100,
            strokeWidth: 3,
            backgroundColor: Colors.grey.shade100,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4A72B2)),
          ),
        ),
        Text(
          '$percentage%',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4A72B2),
          ),
        ),
      ],
    );
  }
}
