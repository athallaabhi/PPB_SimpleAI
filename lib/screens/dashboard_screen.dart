import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/room.dart';
import '../providers/app_state.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'canvas_screen.dart';
import 'gateway_screen.dart';
import 'map_setup_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  final AuthService _authService = AuthService();

  late Future<List<Room>> _roomsFuture;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _currentUid = context.read<AppState>().uid;
    _roomsFuture = _loadRooms();
  }

  Future<List<Room>> _loadRooms() async {
    if (_currentUid == null) {
      return const [];
    }
    return _databaseService.getRoomsByUser(_currentUid!);
  }

  Future<void> _refreshRooms() async {
    setState(() {
      _roomsFuture = _loadRooms();
    });
  }

  Future<void> _logout() async {
    try {
      await _authService.logout();
      if (!mounted) {
        return;
      }
      context.read<AppState>().clearUid();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const GatewayScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed: $error')));
    }
  }

  Future<void> _confirmDeleteRoom(Room room) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete map?'),
              content: Text(
                'Delete "${room.name}" and all associated signal points?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || _currentUid == null) {
      return;
    }

    try {
      await _databaseService.deleteRoom(roomId: room.id, userUid: _currentUid!);
      await _refreshRooms();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete map: $error')));
    }
  }

  Future<void> _editRoomName(Room room) async {
    if (_currentUid == null) {
      return;
    }

    final controller = TextEditingController(text: room.name);
    final updatedName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit map name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Map name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (updatedName == null || updatedName.isEmpty) {
      return;
    }

    try {
      await _databaseService.updateRoomName(
        roomId: room.id,
        userUid: _currentUid!,
        name: updatedName,
      );
      await _refreshRooms();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update map: $error')));
    }
  }

  Future<void> _openMapSetup() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const MapSetupScreen()),
    );

    if (created == true) {
      await _refreshRooms();
    }
  }

  Future<void> _openCanvas(Room room) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CanvasScreen(room: room)),
    );
    await _refreshRooms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari Wifi Paling Kenceng di mana'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openMapSetup,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Room>>(
        future: _roomsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load maps: ${snapshot.error}'),
              ),
            );
          }

          final rooms = snapshot.data ?? const [];
          if (rooms.isEmpty) {
            return const Center(
              child: Text(
                'No maps yet. Tap + to create your first floorplan map.',
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshRooms,
            child: ListView.builder(
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index];

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Stack(
                    children: [
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        elevation: 1,
                        child: ListTile(
                          onTap: () => _openCanvas(room),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          title: Text(room.name),
                          subtitle: const Text('Tap to open canvas'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: 'Edit name',
                                onPressed: () => _editRoomName(room),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.red,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _confirmDeleteRoom(room),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.delete,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
