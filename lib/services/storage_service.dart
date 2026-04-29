import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../firebase_options.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadFloorplan({
    required String uid,
    required File imageFile,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final objectPath = 'floorplans/$uid/$now.jpg';

    try {
      return await _uploadAndReturnUrl(
        storage: _storage,
        objectPath: objectPath,
        imageFile: imageFile,
      );
    } catch (error) {
      if (!_shouldTryFallback(error)) {
        rethrow;
      }

      final fallbackStorage = _buildFallbackStorage();
      if (fallbackStorage != null) {
        try {
          return await _uploadAndReturnUrl(
            storage: fallbackStorage,
            objectPath: objectPath,
            imageFile: imageFile,
          );
        } catch (fallbackError) {
          if (!_shouldTryFallback(fallbackError)) {
            rethrow;
          }
        }
      }

      // Storage bucket can be unavailable (404). Keep map creation working
      // by storing a local floorplan file URI as a fallback.
      return _saveFloorplanLocally(
        uid: uid,
        timestamp: now,
        imageFile: imageFile,
      );
    }
  }

  Future<String> resolveImageUrlForDisplay(String storedImageRef) async {
    if (storedImageRef.startsWith('file://')) {
      return storedImageRef;
    }

    if (storedImageRef.startsWith('http://') ||
        storedImageRef.startsWith('https://')) {
      return storedImageRef;
    }

    final refs = _buildReferenceCandidates(storedImageRef);
    FirebaseException? lastError;

    for (final ref in refs) {
      try {
        return await _getDownloadUrlWithRetry(ref);
      } on FirebaseException catch (error) {
        lastError = error;
      }
    }

    throw lastError ??
        FirebaseException(
          plugin: 'firebase_storage',
          code: 'download-url-unavailable',
          message: 'Unable to resolve floorplan image URL.',
        );
  }

  Future<String> _uploadAndReturnUrl({
    required FirebaseStorage storage,
    required String objectPath,
    required File imageFile,
  }) async {
    final ref = storage.ref().child(objectPath);
    final snapshot = await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    if (snapshot.state != TaskState.success) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'upload-failed',
        message: 'Floorplan upload did not finish successfully.',
      );
    }

    return await ref.getDownloadURL();
  }

  Future<String> _getDownloadUrlWithRetry(Reference ref) async {
    FirebaseException? lastError;

    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        return await ref.getDownloadURL();
      } on FirebaseException catch (error) {
        lastError = error;
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }

    throw lastError ??
        FirebaseException(
          plugin: 'firebase_storage',
          code: 'download-url-unavailable',
          message: 'Unable to resolve floorplan image URL.',
        );
  }

  bool _shouldTryFallback(Object error) {
    if (error is! FirebaseException) {
      return false;
    }

    final code = error.code.toLowerCase();
    if (code.contains('bucket-not-found') || code.contains('not-found')) {
      return true;
    }

    final message = (error.message ?? '').toLowerCase();
    return message.contains('404');
  }

  FirebaseStorage? _buildFallbackStorage() {
    final configuredBucket = DefaultFirebaseOptions.android.storageBucket;
    final fallbackBucket = _alternateBucket(configuredBucket);
    if (fallbackBucket == null || fallbackBucket == _storage.bucket) {
      return null;
    }

    return FirebaseStorage.instanceFor(bucket: fallbackBucket);
  }

  String? _alternateBucket(String? bucket) {
    if (bucket == null || bucket.isEmpty) {
      return null;
    }

    if (bucket.endsWith('.firebasestorage.app')) {
      return bucket.replaceFirst('.firebasestorage.app', '.appspot.com');
    }

    if (bucket.endsWith('.appspot.com')) {
      return bucket.replaceFirst('.appspot.com', '.firebasestorage.app');
    }

    return null;
  }

  Future<String> _saveFloorplanLocally({
    required String uid,
    required int timestamp,
    required File imageFile,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final floorplanDir = Directory(path.join(docsDir.path, 'floorplans', uid));

    if (!await floorplanDir.exists()) {
      await floorplanDir.create(recursive: true);
    }

    final targetFile = File(path.join(floorplanDir.path, '$timestamp.jpg'));
    await imageFile.copy(targetFile.path);
    return Uri.file(targetFile.path).toString();
  }

  List<Reference> _buildReferenceCandidates(String storedImageRef) {
    final refs = <Reference>[];

    if (storedImageRef.startsWith('gs://')) {
      try {
        final uri = Uri.parse(storedImageRef);
        final bucket = uri.host;
        final fullPath = uri.path.startsWith('/')
            ? uri.path.substring(1)
            : uri.path;
        if (bucket.isNotEmpty && fullPath.isNotEmpty) {
          refs.add(FirebaseStorage.instanceFor(bucket: bucket).ref(fullPath));
        }
      } catch (_) {
        // Ignore parse errors and fall back to other strategies.
      }
    }

    if (!storedImageRef.startsWith('http://') &&
        !storedImageRef.startsWith('https://') &&
        !storedImageRef.startsWith('gs://')) {
      refs.add(_storage.ref().child(storedImageRef));
    }

    return refs;
  }
}
