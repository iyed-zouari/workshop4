import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase/supabase.dart';
import 'models/client.dart';
import 'providers/queue_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with your actual values
  const supabaseUrl = 'https://rcfhiivyvtgichpsopkn.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJjZmhpaXZ5dnRnaWNocHNvcGtuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTkzNDQ5NTUsImV4cCI6MjA3NDkyMDk1NX0.1FDV-f2DxdA-W_ncfSa_xcWn93M37oSiK-CYIMgJy2A';

  // Initialize Supabase client
  final supabaseClient = SupabaseClient(supabaseUrl, supabaseAnonKey);

  runApp(MyApp(supabaseClient: supabaseClient));
}

class MyApp extends StatelessWidget {
  final SupabaseClient supabaseClient;

  const MyApp({super.key, required this.supabaseClient});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => QueueProvider(supabaseClient: supabaseClient),
      child: MaterialApp(
        title: 'Waiting Room',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const WaitingRoomScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class WaitingRoomScreen extends StatefulWidget {
  const WaitingRoomScreen({super.key});

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isAdding = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting Room'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<QueueProvider>().refreshClients();
            },
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              _testConnection(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Input Section
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Enter client name',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onSubmitted: (name) {
                      _addClient(context, name);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _isAdding
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: () {
                    _addClient(context, _nameController.text);
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Queue Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current Queue',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Consumer<QueueProvider>(
                  builder: (context, provider, child) {
                    return Text(
                      '${provider.clients.length} clients',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Queue List
            Expanded(
              child: Consumer<QueueProvider>(
                builder: (context, provider, child) {
                  if (provider.clients.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No one in queue yet...',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add the first client to get started!',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      await context.read<QueueProvider>().refreshClients();
                    },
                    child: ListView.builder(
                      itemCount: provider.clients.length,
                      itemBuilder: (context, index) {
                        final client = provider.clients[index];
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Card(
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                client.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                'Added: ${_formatDate(client.createdAt)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  _showDeleteDialog(context, client);
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // Next Button
            const SizedBox(height: 20),
            Consumer<QueueProvider>(
              builder: (context, provider, child) {
                return ElevatedButton.icon(
                  onPressed: provider.clients.isEmpty ? null : () {
                    provider.nextClient();
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(
                    provider.clients.isEmpty ? 'Queue Empty' : 'Next Client',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: provider.clients.isEmpty ? Colors.grey : Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addClient(BuildContext context, String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      _showSnackBar(context, 'Please enter a name');
      return;
    }

    setState(() {
      _isAdding = true;
    });

    try {
      await context.read<QueueProvider>().addClient(trimmedName);
      _nameController.clear();
      _showSnackBar(context, 'Added $trimmedName to queue');
    } catch (e) {
      _showSnackBar(context, 'Error adding client: $e');
    } finally {
      setState(() {
        _isAdding = false;
      });
    }
  }

  void _showDeleteDialog(BuildContext context, Client client) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Client'),
          content: Text('Are you sure you want to remove ${client.name} from the queue?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                context.read<QueueProvider>().removeClient(client.id);
                Navigator.of(context).pop();
                _showSnackBar(context, 'Removed ${client.name} from queue');
              },
              child: const Text(
                'Remove',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _testConnection(BuildContext context) async {
    final provider = context.read<QueueProvider>();

    try {
      print('=== TESTING SUPABASE CONNECTION ===');
      final response = await provider.supabaseClient
          .from('clients')
          .select('*')
          .limit(1);

      print('Test connection response: $response');

      _showSnackBar(context, 'Connection successful! Found ${response.length} items');
    } catch (e) {
      print('Connection test failed: $e');
      _showSnackBar(context, 'Connection failed: $e');
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}