import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/storage_service.dart';

class DocsManagementPage extends StatefulWidget {
  const DocsManagementPage({Key? key}) : super(key: key);

  @override
  _DocsManagementPageState createState() => _DocsManagementPageState();
}

class _DocsManagementPageState extends State<DocsManagementPage> {
  final StorageService _storage = StorageService();
  List<String> _files = [];
  String? _error;
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final objects = await _storage.listFiles();
      setState(() => _files = objects.map((o) => o.name).toList());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null) return;
    final name = result.files.first.name;
    final bytes = result.files.first.bytes!;
    try {
      await _storage.uploadFile(name, bytes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('File uploaded successfully'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
      await _loadFiles();
    } catch (e) {
      setState(() => _error = 'Upload failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showRenameDialog(String oldName) async {
    final controller = TextEditingController(text: oldName);
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: SizedBox(
          width: 300, // decreased width
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFF2F3296),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        'Rename File',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
              // Input
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    24, 24, 24, 8), // increased top padding
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.only(bottom: 8),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black54),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF3F51B5)),
                    ),
                  ),
                ),
              ),
              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    0, 16, 8, 24), // increased bottom padding
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.black),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        final newName = controller.text.trim();
                        if (newName.isEmpty || newName == oldName) return;
                        try {
                          await _storage.renameFile(oldName, newName);
                          Navigator.of(context).pop();
                          await _loadFiles();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('File renamed successfully'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        } catch (e) {
                          setState(() => _error = 'Rename failed: $e');
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Rename failed: $e'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: const Text('Rename'),
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.black),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredFiles = _searchQuery.isEmpty
        ? _files
        : _files
            .where((name) =>
                name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'Document Management',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Container(
              width: 1000,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search filename...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _uploadFile,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: Row(
                      children: const [
                        Expanded(
                            flex: 3,
                            child: Text('Filename',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(
                            flex: 1,
                            child: Text('Actions',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 400,
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView.builder(
                        itemCount: filteredFiles.length,
                        itemBuilder: (c, i) {
                          final name = filteredFiles[i];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                  bottom:
                                      BorderSide(color: Colors.grey.shade200)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(name,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_red_eye),
                                        onPressed: () async {
                                          final url = await _storage
                                              .getDownloadUrl(name);
                                          await launchUrl(Uri.parse(url),
                                              webOnlyWindowName: '_blank');
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () =>
                                            _showRenameDialog(name),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () async {
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text('Delete File'),
                                              content: Text('Delete "$name"?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(true),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (ok ?? false) {
                                            await _storage.deleteFile(name);
                                            await _loadFiles();
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content:
                                                    const Text('File deleted'),
                                                duration:
                                                    const Duration(seconds: 2),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
