class Task {
  final int? id;
  final String title;
  final String description;
  final String status;
  final String createdAt;
  final String updatedAt;

  Task({
    this.id,
    required this.title,
    this.description = '',
    this.status = 'pending',
    this.createdAt = '',
    this.updatedAt = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'status': status,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
        id: map['id'] as int?,
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        status: map['status'] as String? ?? 'pending',
        createdAt: map['created_at'] as String? ?? '',
        updatedAt: map['updated_at'] as String? ?? '',
      );
}
