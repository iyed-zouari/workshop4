class Client {
  final String id;
  final String name;
  final DateTime createdAt;

  Client({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory Client.fromMap(Map<String, dynamic> map) {
    try {
      // Handle ID - could be string, int, or other
      String id;
      if (map['id'] == null) {
        id = 'unknown';
      } else if (map['id'] is String) {
        id = map['id'] as String;
      } else {
        id = map['id'].toString();
      }

      // Handle Name
      String name;
      if (map['name'] == null) {
        name = 'Unknown';
      } else if (map['name'] is String) {
        name = map['name'] as String;
      } else {
        name = map['name'].toString();
      }

      // Handle Created At
      DateTime createdAt;
      if (map['created_at'] == null) {
        createdAt = DateTime.now();
      } else if (map['created_at'] is String) {
        try {
          createdAt = DateTime.parse(map['created_at'] as String);
        } catch (e) {
          print('Error parsing date string: ${map['created_at']}');
          createdAt = DateTime.now();
        }
      } else if (map['created_at'] is DateTime) {
        createdAt = map['created_at'] as DateTime;
      } else {
        createdAt = DateTime.now();
      }

      return Client(
        id: id,
        name: name,
        createdAt: createdAt,
      );
    } catch (e) {
      print('Error in Client.fromMap: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Client(id: $id, name: $name, createdAt: $createdAt)';
  }
}