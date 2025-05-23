import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final _bucket = Supabase.instance.client.storage.from('pdf-files');
  final _folder = 'documents/';

  /// LIST all files in `documents/`
  Future<List<FileObject>> listFiles() async {
    try {
      final files = await _bucket.list(path: _folder);
      print('Supabase returned ${files.length} file(s) in "$_folder"');
      return files;
    } catch (e) {
      print('Error listing files: $e');
      rethrow;
    }
  }

  /// UPLOAD a file
  Future<void> uploadFile(String fileName, Uint8List bytes) async {
    try {
      await _bucket.uploadBinary(
        '$_folder$fileName',
        bytes,
        fileOptions: const FileOptions(upsert: false),
      );
      print('Uploaded file: $fileName');
    } catch (e) {
      print('Error uploading file: $e');
      rethrow;
    }
  }

  /// GET a signed download URL
  Future<String> getDownloadUrl(String fileName) {
    return _bucket.createSignedUrl('$_folder$fileName', 60 * 5);
  }

  /// RENAME / MOVE a file
  Future<void> renameFile(String oldName, String newName) {
    return _bucket.move('$_folder$oldName', '$_folder$newName');
  }

  /// DELETE a file
  Future<void> deleteFile(String fileName) {
    return _bucket.remove(['$_folder$fileName']).then((_) {
      print('Deleted file: $fileName');
    });
  }
}
