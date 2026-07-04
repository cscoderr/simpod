class SimpodSession {
  SimpodSession({
    required this.pid,
    required this.port,
    required this.device,
    required this.url,
    required this.accessToken,
    required this.streamUrl,
    required this.wsUrl,
  });
  factory SimpodSession.fromJson(Map<String, dynamic> json) {
    return SimpodSession(
      pid: json['pid'] as int,
      port: json['port'] as int,
      device: json['device'] as String,
      url: json['url'] as String,
      accessToken: json['accessToken'] as String?,
      streamUrl: json['streamUrl'] as String,
      wsUrl: json['wsUrl'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pid': pid,
      'port': port,
      'device': device,
      'url': url,
      'accessToken': accessToken,
      'streamUrl': streamUrl,
      'wsUrl': wsUrl,
    };
  }

  final int pid;
  final int port;
  final String device;
  final String url;
  final String? accessToken;
  final String streamUrl;
  final String wsUrl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SimpodSession &&
          other.pid == pid &&
          other.port == port &&
          other.device == device &&
          other.url == url &&
          other.accessToken == accessToken &&
          other.streamUrl == streamUrl &&
          other.wsUrl == wsUrl;

  @override
  int get hashCode =>
      pid.hashCode ^
      port.hashCode ^
      device.hashCode ^
      url.hashCode ^
      accessToken.hashCode ^
      streamUrl.hashCode ^
      wsUrl.hashCode;
}
