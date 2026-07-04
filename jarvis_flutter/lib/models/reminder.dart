class Reminder {
  final int? id;
  final String title;
  final String description;
  final String dueDate;
  final bool isDone;
  final String createdAt;

  Reminder({
    this.id,
    required this.title,
    this.description = '',
    this.dueDate = '',
    this.isDone = false,
    this.createdAt = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'due_date': dueDate,
        'is_done': isDone ? 1 : 0,
        'created_at': createdAt,
      };

  factory Reminder.fromMap(Map<String, dynamic> map) => Reminder(
        id: map['id'] as int?,
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        dueDate: map['due_date'] as String? ?? '',
        isDone: (map['is_done'] as int?) == 1,
        createdAt: map['created_at'] as String? ?? '',
      );

  Reminder copyWith({bool? isDone}) => Reminder(
        id: id,
        title: title,
        description: description,
        dueDate: dueDate,
        isDone: isDone ?? this.isDone,
        createdAt: createdAt,
      );
}
