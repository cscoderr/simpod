enum DeviceState {
  booted,
  shutdown,
  unknown;

  static DeviceState fromString(String value) {
    switch (value.toLowerCase()) {
      case 'booted':
        return DeviceState.booted;
      case 'shutdown':
        return DeviceState.shutdown;
      default:
        return DeviceState.unknown;
    }
  }
}

class DeviceInfo {
  const DeviceInfo({
    required this.udid,
    required this.name,
    required this.state,
    required this.runtime,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      udid: json['udid'] as String,
      name: json['name'] as String,
      state: DeviceState.fromString(json['state'] as String),
      runtime: json['runtime'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'udid': udid,
      'name': name,
      'state': state.name,
      'runtime': runtime,
    };
  }

  final String udid;

  final String name;

  final DeviceState state;

  final String runtime;

  String get formattedRuntime {
    return runtime.contains('iOS.')
        ? runtime.replaceAll('iOS.', 'iOS ')
        : runtime;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfo &&
          other.udid == udid &&
          other.name == name &&
          other.state == state &&
          other.runtime == runtime;

  @override
  int get hashCode =>
      udid.hashCode ^ name.hashCode ^ state.hashCode ^ runtime.hashCode;
}
