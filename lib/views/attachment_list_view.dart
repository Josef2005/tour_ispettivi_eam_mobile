import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inspection_activity.dart';
import '../viewmodels/attachment_viewmodel.dart';
import '../models/attachment.dart';

class AttachmentListView extends StatefulWidget {
  final InspectionActivity activity;
  final String activityName;

  const AttachmentListView({
    super.key, 
    required this.activity,
    required this.activityName,
  });

  @override
  State<AttachmentListView> createState() => _AttachmentListViewState();
}

class _AttachmentListViewState extends State<AttachmentListView> {
  late AttachmentViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AttachmentViewModel(
      itemId: widget.activity.idext,
      activityName: widget.activityName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<AttachmentViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Allegati', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(
                      viewModel.activityName.toUpperCase(),
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              backgroundColor: const Color(0xFF4A72B2),
              foregroundColor: Colors.white,
            ),
            body: Stack(
              children: [
                if (viewModel.attachments.isEmpty && !viewModel.isLoading)
                  _buildEmptyState(context, viewModel)
                else
                  _buildListView(context, viewModel),
                if (viewModel.isLoading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AttachmentViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.attach_file, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Nessun allegato presente',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 32),
          _buildAddButton(context, viewModel),
        ],
      ),
    );
  }

  Widget _buildListView(BuildContext context, AttachmentViewModel viewModel) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: viewModel.attachments.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final attachment = viewModel.attachments[index];
              return _buildAttachmentItem(context, viewModel, attachment);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: _buildAddButton(context, viewModel),
        ),
      ],
    );
  }

  Widget _buildAttachmentItem(BuildContext context, AttachmentViewModel viewModel, Attachment attachment) {
    IconData iconData = Icons.insert_drive_file;
    if (attachment.mimeType.startsWith('image/')) {
      iconData = Icons.image;
    } else if (attachment.mimeType.startsWith('video/')) {
      iconData = Icons.videocam;
    }

    return ListTile(
      leading: Icon(iconData, color: const Color(0xFF4A72B2), size: 32),
      title: Text(
        attachment.fileName.length > 30 
            ? '...${attachment.fileName.substring(attachment.fileName.length - 27)}' 
            : attachment.fileName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(attachment.dateUploaded.split('T').first),
      trailing: IconButton(
        icon: const Icon(Icons.delete, color: Colors.redAccent),
        onPressed: () => _confirmDelete(context, viewModel, attachment),
      ),
      onTap: () => viewModel.openAttachment(attachment),
    );
  }

  Widget _buildAddButton(BuildContext context, AttachmentViewModel viewModel) {
    return ElevatedButton.icon(
      onPressed: () => _showAddOptions(context, viewModel),
      icon: const Icon(Icons.add_a_photo),
      label: const Text('AGGIUNGI ALLEGATO'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4A72B2),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 4,
      ),
    );
  }

  void _showAddOptions(BuildContext context, AttachmentViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Aggiungi Allegato',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Color(0xFF4A72B2)),
              title: const Text('File dal dispositivo'),
              onTap: () {
                Navigator.pop(context);
                viewModel.pickFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF4A72B2)),
              title: const Text('Scatta foto'),
              onTap: () {
                Navigator.pop(context);
                viewModel.takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Color(0xFF4A72B2)),
              title: const Text('Registra video (max 10s)'),
              onTap: () {
                Navigator.pop(context);
                viewModel.takeVideo();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AttachmentViewModel viewModel, Attachment attachment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Allegato'),
        content: const Text('Sei sicuro di voler eliminare questo allegato?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ANNULLA'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              viewModel.deleteAttachment(attachment);
            },
            child: const Text('ELIMINA', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
