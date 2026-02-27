import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inspection.dart';
import '../models/inspection_activity.dart';
import '../models/item.dart';
import '../viewmodels/activity_list_viewmodel.dart';
import '../viewmodels/asset_viewmodel.dart';
import 'widgets/activity_list_item.dart';

class InspectionActivityListView extends StatelessWidget {
  final Inspection inspection;
  final String assetId;
  final String assetLabel;
  final List<InspectionActivity> activities;
  final List<Map<String, dynamic>> fullAssetList;
  final VoidCallback? onRefresh;

  const InspectionActivityListView({
    super.key,
    required this.inspection,
    required this.assetId,
    required this.assetLabel,
    required this.activities,
    required this.fullAssetList,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ActivityListViewModel(
        inspection: inspection,
        assetId: assetId,
        assetLabel: assetLabel,
        initialActivities: activities,
      ),
      child: _ActivityListContent(
        fullAssetList: fullAssetList,
        onRefresh: onRefresh,
      ),
    );
  }
}

class _ActivityListContent extends StatelessWidget {
  final List<Map<String, dynamic>> fullAssetList;
  final VoidCallback? onRefresh;

  const _ActivityListContent({
    required this.fullAssetList,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ActivityListViewModel>();
    final nonInMarcia = viewModel.nonInMarcia;

    return Scaffold(
      backgroundColor: const Color(0xFFE8ECEF),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // 1. Top Blue Bar (Original Android Style)
                Container(
                  color: const Color(0xFF4A72B2),
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Image.asset(
                          'assets/images/logo_app.png',
                          height: 32,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.stars, color: Colors.white, size: 30),
                        ),
                      ),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Tour Isp. v.25',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '(ffisica)',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.home, color: Colors.white, size: 28),
                        onPressed: () =>
                            Navigator.of(context).popUntil((route) => route.isFirst),
                      ),
                      IconButton(
                        icon: const Icon(Icons.sync, color: Colors.white, size: 28),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.exit_to_app,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () {
                          if (onRefresh != null) onRefresh!();
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
                // 2. Breadcrumb Bar (Light Blue)
                Container(
                  color: const Color(0xFFD9E2F1),
                  height: 48,
                  padding: const EdgeInsets.only(right: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          size: 20,
                          color: Color(0xFF4A72B2),
                        ),
                        onPressed: () {
                          if (onRefresh != null) onRefresh!();
                          Navigator.of(context).pop();
                        },
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              viewModel.inspection.idext,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4A72B2),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'TOUR: ${viewModel.inspection.getStringDetailValue(Inspection.keyInspectionTour)}'
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF556677),
                                fontSize: 10,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 3. Asset Info Header
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Circular Percentage
                      viewModel.percentage == 100
                          ? const CircleAvatar(
                              radius: 25,
                              backgroundColor: Color(0xFF28A745),
                              child: Icon(Icons.check, color: Colors.white, size: 30),
                            )
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: CircularProgressIndicator(
                                    value: viewModel.percentage / 100,
                                    strokeWidth: 4,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      Color(0xFF4A72B2),
                                    ),
                                  ),
                                ),
                                Text(
                                  '${viewModel.percentage}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4A72B2),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                      const SizedBox(width: 12),
                      // Asset Label & Dropdown
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    viewModel.assetLabel.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            if (viewModel.statiAsset.isNotEmpty)
                              DropdownButtonHideUnderline(
                                child: DropdownButton<Item>(
                                  isDense: true,
                                  value: viewModel.selectedStato,
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: Color(0xFF4A72B2),
                                  ),
                                  items: viewModel.statiAsset
                                      .map(
                                        (s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(
                                            s.description ?? s.code ?? '',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF4A72B2),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) viewModel.selectStatoAsset(val);
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFCCCCCC)),
                // 4. Activity List
                Expanded(
                  child: nonInMarcia == '1'
                      ? const Center(
                          child: Text(
                            'ASSET NON IN MARCIA',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 10, bottom: 80),
                          itemCount: viewModel.activities.length,
                          itemBuilder: (context, index) => ActivityListItem(
                            activity: viewModel.activities[index],
                            viewModel: viewModel,
                          ),
                        ),
                ),
              ],
            ),
            // 5. Continua Button (Floating style at bottom right)
            Positioned(
              right: 12,
              bottom: 12,
              child: Material(
                elevation: 6,
                color: const Color(0xFF4A72B2),
                borderRadius: BorderRadius.circular(4),
                child: InkWell(
                  onTap: () async {
                    // Check mandatory notes for anomalies first
                    final missingNoteAct = viewModel.checkMandatoryNotes();
                    if (missingNoteAct != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Nota obbligatoria per: ${missingNoteAct.description}',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // 1. Block if inspection is not 100% complete
                    if (viewModel.percentage < 100) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Ispezione non completa'),
                          content: const Text(
                            'Impossibile continuare: tutte le attività devono essere completate.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                      return;
                    }

                    // 2. Confirmation Dialog
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Conferma'),
                        content: const Text(
                          'Si vuole considerare l\'ispezione conclusa?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text(
                              'NO',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'SI',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm != true) return;

                    // 3. Success Message (Visible for a few seconds)
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Text(
                            "Operazione Completata",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          content: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF28A745),
                                size: 80,
                              ),
                              SizedBox(height: 20),
                              Text(
                                'Ispezione conclusa con successo.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      );

                      // Wait 2 seconds
                      await Future.delayed(const Duration(seconds: 2));
                      if (context.mounted) Navigator.pop(context); // Close success dialog
                    }

                    // 4. Navigation to next asset or back
                    if (context.mounted) {
                      // Aggiorna la percentuale dell'asset corrente nella lista per evitare navigazione obsoleta
                      final currentIndex = fullAssetList.indexWhere(
                        (asset) => asset['id'] == viewModel.assetId,
                      );
                      if (currentIndex != -1) {
                        fullAssetList[currentIndex]['percentage'] = viewModel.percentage;
                      }

                      final nextAsset = viewModel.getNextIncompleteAsset(fullAssetList);

                      if (nextAsset != null) {
                        // Segnala alla lista principale di rinfrescarsi in background
                        if (onRefresh != null) onRefresh!();

                        // USIAMO pushReplacement per appiattire la catena di navigazione
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => InspectionActivityListView(
                              inspection: viewModel.inspection,
                              assetId: nextAsset['id'],
                              assetLabel: nextAsset['label'],
                              activities: (nextAsset['activities'] as List)
                                  .cast<InspectionActivity>(),
                              fullAssetList: fullAssetList,
                              onRefresh: onRefresh,
                            ),
                          ),
                        );
                      } else {
                        // Se non ci sono più asset, segnaliamo il refresh e torniamo indietro
                        if (onRefresh != null) onRefresh!();
                        Navigator.of(context).pop();
                      }
                    }
                  },
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    alignment: Alignment.center,
                    child: const Text(
                      'CONTINUA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
