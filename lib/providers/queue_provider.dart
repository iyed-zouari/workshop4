import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase/supabase.dart';
import '../models/client.dart';

class QueueProvider extends ChangeNotifier {
  final List<Client> _clients = [];
  List<Client> get clients => List.unmodifiable(_clients);

  final SupabaseClient _supabase;
  RealtimeChannel? _channel;

  QueueProvider({required SupabaseClient supabaseClient}) : _supabase = supabaseClient {
    _initialize();
  }

  Future<void> _initialize() async {
    await refreshClients();
    _setupRealtimeSubscription();
  }

  Future<void> refreshClients() async {
    try {
      print('=== FETCHING CLIENTS FROM SUPABASE ===');

      final response = await _supabase
          .from('clients')
          .select()
          .order('created_at', ascending: true);

      print('Supabase response: $response');

      if (response == null || response is! List) {
        print('Invalid response format');
        _clients.clear();
        notifyListeners();
        return;
      }

      print('Number of items in response: ${response.length}');

      final List<Client> newClients = [];
      for (final item in response) {
        print('Processing item: $item');
        try {
          final client = Client.fromMap(item);
          newClients.add(client);
          print('Successfully created client: ${client.name}');
        } catch (e) {
          print('Error processing item $item: $e');
        }
      }

      _clients.clear();
      _clients.addAll(newClients);
      _clients.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      print('=== FINAL CLIENT COUNT: ${_clients.length} ===');
      notifyListeners();

    } catch (e) {
      print('EXCEPTION in refreshClients: $e');
    }
  }

  void _setupRealtimeSubscription() {
    try {
      print('=== SETTING UP REALTIME SUBSCRIPTION ===');

      // Create channel for clients table
      _channel = _supabase.channel('clients_channel');

      // Subscribe to changes
      _channel!
          .on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(
          event: '*',
          schema: 'public',
          table: 'clients',
        ),
            (payload, [ref]) {
          _handleRealtimeEvent(payload);
        },
      )
          .subscribe((status, [error]) {
        print('=== REALTIME SUBSCRIPTION STATUS: $status ===');
        if (status == 'SUBSCRIBED') {
          print('=== REALTIME SUBSCRIPTION ACTIVE ===');
        } else if (status == 'TIMED_OUT') {
          print('=== REALTIME SUBSCRIPTION TIMEOUT ===');
        } else if (error != null) {
          print('=== REALTIME SUBSCRIPTION ERROR: $error ===');
        }
      });

    } catch (e) {
      print('Error setting up realtime subscription: $e');
    }
  }

  void _handleRealtimeEvent(Map<String, dynamic> payload) {
    try {
      final String eventType = payload['eventType'] ?? '';
      final Map<String, dynamic> newRecord = payload['new'] ?? {};
      final Map<String, dynamic> oldRecord = payload['old'] ?? {};

      print('=== REALTIME EVENT: $eventType ===');
      print('New record: $newRecord');
      print('Old record: $oldRecord');

      switch (eventType) {
        case 'INSERT':
          _handleInsertEvent(newRecord);
          break;
        case 'UPDATE':
          _handleUpdateEvent(newRecord);
          break;
        case 'DELETE':
          _handleDeleteEvent(oldRecord);
          break;
        default:
          print('Unknown event type: $eventType');
      }
    } catch (e) {
      print('Error handling realtime event: $e');
    }
  }

  void _handleInsertEvent(Map<String, dynamic> newRecord) {
    try {
      final newClient = Client.fromMap(newRecord);
      _clients.add(newClient);
      _clients.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      print('=== CLIENT ADDED VIA REALTIME: ${newClient.name} ===');
      notifyListeners();
    } catch (e) {
      print('Error handling insert event: $e');
    }
  }

  void _handleUpdateEvent(Map<String, dynamic> newRecord) {
    try {
      final updatedClient = Client.fromMap(newRecord);
      final index = _clients.indexWhere((client) => client.id == updatedClient.id);
      if (index != -1) {
        _clients[index] = updatedClient;
        print('=== CLIENT UPDATED VIA REALTIME: ${updatedClient.name} ===');
        notifyListeners();
      }
    } catch (e) {
      print('Error handling update event: $e');
    }
  }

  void _handleDeleteEvent(Map<String, dynamic> oldRecord) {
    try {
      final deletedId = oldRecord['id']?.toString();
      if (deletedId != null) {
        _clients.removeWhere((client) => client.id == deletedId);
        print('=== CLIENT DELETED VIA REALTIME: $deletedId ===');
        notifyListeners();
      }
    } catch (e) {
      print('Error handling delete event: $e');
    }
  }

  Future<void> addClient(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      print('Cannot add empty client name');
      return;
    }

    try {
      print('=== ADDING CLIENT: $trimmedName ===');
      await _supabase
          .from('clients')
          .insert({'name': trimmedName});

      print('Client added to database: $trimmedName');
    } catch (e) {
      print('Exception adding client: $e');
    }
  }

  Future<void> removeClient(String id) async {
    try {
      print('=== REMOVING CLIENT: $id ===');
      await _supabase
          .from('clients')
          .delete()
          .match({'id': id});

      print('Client removed from database: $id');
    } catch (e) {
      print('Exception removing client: $e');
    }
  }

  Future<void> nextClient() async {
    if (_clients.isEmpty) {
      print('Queue is empty!');
      return;
    }

    final firstClient = _clients.first;
    await removeClient(firstClient.id);
    print('Next client: ${firstClient.name}');
  }

  // Getter for testing
  SupabaseClient get supabaseClient => _supabase;

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}