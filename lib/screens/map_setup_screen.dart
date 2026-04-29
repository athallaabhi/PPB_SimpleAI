import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class MapSetupScreen extends StatefulWidget {
  const MapSetupScreen({super.key});

  @override
  State<MapSetupScreen> createState() => _MapSetupScreenState();
}

class _MapSetupScreenState extends State<MapSetupScreen> {
  final TextEditingController _mapNameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  final DatabaseService _databaseService = DatabaseService.instance;

  File? _pickedImage;
  bool _isSaving = false;

  @override
  void dispose() {
    _mapNameController.dispose();
    super.dispose();
  }

  Future<void> _selectImageSource(ImageSource source) async {
    Navigator.pop(context);

    try {
      final selected = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (selected == null) {
        return;
      }

      setState(() {
        _pickedImage = File(selected.path);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to get image: $error')));
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => _selectImageSource(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => _selectImageSource(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveMap() async {
    final mapName = _mapNameController.text.trim();
    final uid = context.read<AppState>().uid;

    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No authenticated user found.')),
      );
      return;
    }

    if (mapName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Map name is required.')));
      return;
    }

    if (_pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a floorplan image first.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final downloadUrl = await _storageService.uploadFloorplan(
        uid: uid,
        imageFile: _pickedImage!,
      );

      await _databaseService.insertRoom(
        userUid: uid,
        name: mapName,
        imageUrl: downloadUrl,
      );

      await NotificationService.instance.showMapSavedNotification(mapName);

      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('Map save failed: $error');
      debugPrintStack(label: 'Map save stack trace', stackTrace: stackTrace);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save map: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _mapNameController,
              decoration: const InputDecoration(
                labelText: 'Map Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GestureDetector(
                onTap: _showImageSourceSheet,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueGrey, width: 1.2),
                    color: Colors.blueGrey.shade50,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _pickedImage == null
                      ? const Center(
                          child: Text(
                            'Tap to Add Floorplan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : Image.file(
                          _pickedImage!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveMap,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Map'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
