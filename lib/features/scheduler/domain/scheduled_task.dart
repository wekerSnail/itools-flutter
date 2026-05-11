enum ScheduledTaskType { jsScript, terminalCommand }

enum ScheduleUnit { second, minute, hour, day, week, month }

enum TaskVariableType { string, number, boolean, object }

ScheduleUnit parseScheduleUnit(String? raw) {
  switch (raw) {
    case 'second':
      return ScheduleUnit.second;
    case 'minute':
      return ScheduleUnit.minute;
    case 'hour':
      return ScheduleUnit.hour;
    case 'day':
      return ScheduleUnit.day;
    case 'week':
      return ScheduleUnit.week;
    case 'month':
      return ScheduleUnit.month;
    default:
      return ScheduleUnit.minute;
  }
}

TaskVariableType parseTaskVariableType(String? raw) {
  switch (raw) {
    case 'string':
      return TaskVariableType.string;
    case 'number':
      return TaskVariableType.number;
    case 'boolean':
      return TaskVariableType.boolean;
    case 'object':
      return TaskVariableType.object;
    default:
      return TaskVariableType.string;
  }
}

class TaskVariable {
  TaskVariable({required this.name, required this.type, required this.value});

  final String name;
  final TaskVariableType type;
  final dynamic value;

  TaskVariable copyWith({String? name, TaskVariableType? type, dynamic value}) {
    return TaskVariable(
      name: name ?? this.name,
      type: type ?? this.type,
      value: value ?? this.value,
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'type': type.name, 'value': value};
  }

  factory TaskVariable.fromJson(Map<String, dynamic> json) {
    final type = parseTaskVariableType(json['type'] as String?);
    final raw = json['value'];
    return TaskVariable(
      name: json['name'] as String,
      type: type,
      value: switch (type) {
        TaskVariableType.number =>
          raw is num ? raw : num.tryParse(raw.toString()) ?? 0,
        TaskVariableType.boolean =>
          raw == true || raw.toString().toLowerCase() == 'true',
        _ => raw,
      },
    );
  }
}

ScheduledTaskType parseScheduledTaskType(String? raw) {
  switch (raw) {
    case 'jsScript':
      return ScheduledTaskType.jsScript;
    case 'terminalCommand':
      return ScheduledTaskType.terminalCommand;
    default:
      return ScheduledTaskType.terminalCommand;
  }
}

class ScheduledTask {
  ScheduledTask({
    required this.id,
    required this.name,
    required this.type,
    required this.command,
    required this.startAt,
    required this.intervalValue,
    required this.intervalUnit,
    required this.variables,
    required this.enabled,
    this.script,
  });

  final String id;
  final String name;
  final ScheduledTaskType type;
  final String command;
  final DateTime startAt;
  final int intervalValue;
  final ScheduleUnit intervalUnit;
  final List<TaskVariable> variables;
  final bool enabled;
  final String? script;

  Map<String, dynamic> get runtimeVariables {
    return {for (final v in variables) v.name: v.value};
  }

  ScheduledTask copyWith({
    String? id,
    String? name,
    ScheduledTaskType? type,
    String? command,
    DateTime? startAt,
    int? intervalValue,
    ScheduleUnit? intervalUnit,
    List<TaskVariable>? variables,
    bool? enabled,
    String? script,
    bool clearScript = false,
  }) {
    return ScheduledTask(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      command: command ?? this.command,
      startAt: startAt ?? this.startAt,
      intervalValue: intervalValue ?? this.intervalValue,
      intervalUnit: intervalUnit ?? this.intervalUnit,
      variables: variables ?? this.variables,
      enabled: enabled ?? this.enabled,
      script: clearScript ? null : (script ?? this.script),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'command': command,
      'startAt': startAt.toIso8601String(),
      'intervalValue': intervalValue,
      'intervalUnit': intervalUnit.name,
      'variables': variables.map((e) => e.toJson()).toList(growable: false),
      'enabled': enabled,
      'script': script,
    };
  }

  factory ScheduledTask.fromJson(Map<String, dynamic> json) {
    final variablesRaw = json['variables'];

    final parsedVariables = switch (variablesRaw) {
      final List<dynamic> list =>
        list
            .map((e) => TaskVariable.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      final Map<String, dynamic> map =>
        map.entries
            .map(
              (e) => TaskVariable(
                name: e.key,
                type: TaskVariableType.string,
                value: e.value.toString(),
              ),
            )
            .toList(growable: false),
      _ => <TaskVariable>[],
    };

    final intervalValueRaw =
        json['intervalValue'] ?? json['intervalMinutes'] ?? 5;
    final intervalValue = intervalValueRaw is num
        ? intervalValueRaw.toInt()
        : int.tryParse(intervalValueRaw.toString()) ?? 5;

    return ScheduledTask(
      id: json['id'] as String,
      name: json['name'] as String,
      type: parseScheduledTaskType(json['type'] as String?),
      command: json['command'] as String? ?? '',
      startAt: DateTime.parse(json['startAt'] as String),
      intervalValue: intervalValue,
      intervalUnit: parseScheduleUnit(json['intervalUnit'] as String?),
      variables: parsedVariables,
      enabled: json['enabled'] as bool? ?? true,
      script: json['script'] as String?,
    );
  }
}
