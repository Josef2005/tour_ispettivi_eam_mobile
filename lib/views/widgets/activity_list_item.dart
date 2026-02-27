import 'package:flutter/material.dart';
import '../../models/inspection_activity.dart';
import '../../viewmodels/activity_list_viewmodel.dart';

import '../attachment_list_view.dart';

class ActivityListItem extends StatelessWidget {
  final InspectionActivity activity;
  final ActivityListViewModel viewModel;

  const ActivityListItem({
    super.key,
    required this.activity,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      elevation: 4,
      shadowColor: Colors.black45,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFA1A1A0), width: 1), // grigioChiaro
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            _buildInput(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    Color textColor = Colors.black;
    final anomalia = activity.getAnomalia();
    final risposta = activity.getRisposta();
    final nota = activity.getNota();
    final nonInMarcia = activity.getStringDetailValue('NonInMarcia');

    if (anomalia == '1') {
      textColor = const Color(0xFFFF0000); // Rosso Android
    } else if (InspectionActivity.checkAnswer(risposta) || nota.trim().isNotEmpty || nonInMarcia == '1') {
      textColor = const Color(0xFF28A745); // Verde Android
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            (activity.getStringDetailValueLabel('AttivitaID').isEmpty 
                ? activity.description ?? '' 
                : activity.getStringDetailValueLabel('AttivitaID')).toUpperCase(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Attachment Icon (Paperclip)
        Stack(
          clipBehavior: Clip.none,
          children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AttachmentListView(
                      activity: activity,
                      activityName: (activity.getStringDetailValueLabel('AttivitaID').isEmpty 
                        ? activity.description ?? '' 
                        : activity.getStringDetailValueLabel('AttivitaID')),
                    ),
                  ),
                ).then((_) {
                  viewModel.loadAttachmentCounts();
                });
              },
              child: Image.asset(
                'assets/images/icons/ic_document.png',
                width: 40,
                height: 40,
                color: const Color(0xFF515150), // grigioScuro
              ),
            ),
            if (viewModel.getAttachmentCount(activity.idext) > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    '${viewModel.getAttachmentCount(activity.idext)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
        // Note Icon (Document)
        InkWell(
          onTap: () => _showNoteDialog(context),
          child: Image.asset(
            nota.trim().isNotEmpty 
              ? 'assets/images/icons/ic_card_small.png' 
              : 'assets/images/icons/ic_card_light_small.png',
            width: 40,
            height: 40,
            color: const Color(0xFF515150), // grigioScuro
          ),
        ),
      ],
    );
  }

  Widget _buildInput(BuildContext context) {
    final tipo = activity.getTipoRisposta();
    switch (tipo) {
      case '1':
        return _buildTextInput(context);
      case '2':
        return _buildDropdownInput(context);
      case '3':
        return _buildButtonsInput(context);
      default:
        return _buildTextInput(context);
    }
  }

  Widget _buildTextInput(BuildContext context) {
    final controller = TextEditingController(text: activity.getRisposta());
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Valore...',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) => viewModel.updateActivityResponse(activity, value),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          activity.getStringDetailValueLabel('UnitaMisura'),
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildDropdownInput(BuildContext context) {
    final values = activity.details.where((d) => d.name.startsWith('VALORE_')).toList();
    if (values.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: const Text('Seleziona...'),
          value: activity.getRisposta().isEmpty ? null : activity.getRisposta(),
          items: [
            const DropdownMenuItem(value: '', child: Text(' - ')),
            ...values.map((v) => DropdownMenuItem(
                  value: v.name,
                  child: Text(v.value?.split(':')[0] ?? ''),
                )),
          ],
          onChanged: (val) {
            if (val != null) {
              viewModel.updateActivityResponse(activity, val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildButtonsInput(BuildContext context) {
    final currentResponse = activity.getRisposta().toLowerCase();

    return Row(
      children: [
        _buildResponseButton(
          label: 'OK',
          color: const Color(0xFF28A745), // Verde Android
          isSelected: currentResponse == 'true' || currentResponse == '1',
          onTap: () => viewModel.updateActivityResponse(activity, 'True'),
        ),
        const SizedBox(width: 6),
        _buildResponseButton(
          label: 'ANOMALIA',
          color: const Color(0xFFFF0000), // Rosso Android
          isSelected: currentResponse == 'false' || currentResponse == '0',
          onTap: () async {
            final oldResponse = activity.getRisposta();
            await viewModel.updateActivityResponse(activity, 'False');
            if (context.mounted) {
              _showNoteDialog(context, isMandatory: true, onCancel: () {
                viewModel.updateActivityResponse(activity, oldResponse);
              });
            }
          },
        ),
        const SizedBox(width: 6),
        _buildResponseButton(
          label: 'N.A.',
          color: const Color(0xFFF7A618), // Giallo Android
          isSelected: currentResponse == 'null' || currentResponse == 'NULL',
          onTap: () => viewModel.updateActivityResponse(activity, 'NULL'),
        ),
      ],
    );
  }

  Widget _buildResponseButton({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: isSelected ? color : const Color(0xFFA1A1A0), // GrigioChiaro Android
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showNoteDialog(BuildContext context, {bool isMandatory = false, VoidCallback? onCancel}) {
    final controller = TextEditingController(text: activity.getNota());
    showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            if (isMandatory) const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 30),
            if (isMandatory) const SizedBox(width: 8),
            Expanded(
              child: Text(
                isMandatory ? 'Nota obbligatoria per attività in anomalia' : 'Inserisci Nota',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (activity.getStringDetailValueLabel('AttivitaID').isEmpty 
                  ? activity.description ?? '' 
                  : activity.getStringDetailValueLabel('AttivitaID')).toUpperCase(),
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Scrivi qui...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (onCancel != null) onCancel();
              Navigator.pop(context);
            },
            child: const Text('ANNULLA', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () {
              if (isMandatory && controller.text.trim().isEmpty) {
                return; // Non chiudere se obbligatoria e vuota
              }
              viewModel.updateActivityNote(activity, controller.text);
              Navigator.pop(context);
            },
            child: const Text('OK', style: TextStyle(color: Color(0xFF4A72B2), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
