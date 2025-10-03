import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase/supabase.dart';
import '../models/client.dart';

class QueueProvider extends ChangeNotifier {
  final List<Client> _clients = [];
  List<Client> get clients => List.unmodifiable(_clients);

  final SupabaseClient _supabase;
  Timer? _pollingTimer;
  bool _isLoading = false;

  QueueProvider({required SupabaseClient supabaseClient}) : _supabase = supabaseClient {
    _initialize();
  }

  Future<void> _initialize() async {
    await refreshClients();
    _startPolling();
  }

  Future<void> refreshClients() async {
    if (_isLoading) return;

    _isLoading = true;
    try {
      print('=== FETCHING CLIENTS FROM SUPABASE ===');

      final response = await _supabase
          .from('clients')
          .select()
          .order('created_at', ascending: true);

      print('Supabase response type: ${response.runtimeType}');
      print('Supabase response: $response');

      // Check if response is null or empty
      if (response == null) {
        print('Response is NULL');
        _clients.clear();
        notifyListeners();
        return;
      }

      if (response is! List) {
        print('Response is not a List. Type: ${response.runtimeType}');
        _clients.clear();
        notifyListeners();
        return;
      }

      print('Number of items in response: ${response.length}');

      final List<Client> newClients = [];
      for (final item in response) {
        print('Processing item: $item (type: ${item.runtimeType})');
        try {
          final client = Client.fromMap(item);
          newClients.add(client);
          print('Successfully created client: ${client.name}');
        } catch (e) {
          print('Error processing item $item: $e');
        }
      }

      // Update the list
      _clients.clear();
      _clients.addAll(newClients);
      _clients.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      print('=== FINAL CLIENT COUNT: ${_clients.length} ===');
      notifyListeners();

    } catch (e) {
      print('EXCEPTION in refreshClients: $e');
    } finally {
      _isLoading = false;
    }
  }

  void _startPolling() {
    // Poll every 3 seconds for updates
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      refreshClients();
    });
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

      // Force an immediate refresh after adding
      await refreshClients();
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

      // Force an immediate refresh after removal
      await refreshClients();
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
    _pollingTimer?.cancel();
    super.dispose();
  }
}