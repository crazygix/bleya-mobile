import 'package:socket_io_client/socket_io_client.dart' as io;

/// A packet the app sent to the server.
class SentPacket {
  final String event;
  final dynamic data;
  final Function? ack;

  /// Whether the socket was connected when the app sent it. A real socket
  /// queues packets sent while disconnected and sends them on reconnect.
  final bool whileConnected;

  SentPacket(this.event, this.data, this.ack, {required this.whileConnected});

  /// Answers the packet's acknowledgement, as the server does.
  void reply([Object? response]) {
    final callback = ack;
    if (callback == null) {
      throw StateError('$event was sent without an acknowledgement');
    }
    Function.apply(callback, response == null ? const [] : [response]);
  }
}

/// A socket.io client socket that never opens a connection. The test plays
/// the server: it accepts or refuses the connection, sends events, drops or
/// ends the connection, and reads what the app sent in [sent].
///
/// It drives the socket through socket_io_client's own entry points
/// (onconnect, onevent, ondisconnect, onclose), so the app's handlers run as
/// they do with a real server.
class FakeIoSocket extends io.Socket {
  FakeIoSocket(Map<String, dynamic> options)
      : super(
          // A manager that never connects, from the package's own factory.
          io.io('http://socket.test', {
            ...options,
            'autoConnect': false,
            'forceNew': true,
          }).io,
          '/',
          options,
        );

  final List<SentPacket> sent = [];
  int connectCalls = 0;
  int disconnectCalls = 0;

  /// The events the app sent, in order.
  List<String> get sentEvents => [for (final packet in sent) packet.event];

  /// The packets the app sent for [event], in order.
  List<SentPacket> sentFor(String event) => [
        for (final packet in sent)
          if (packet.event == event) packet
      ];

  /// The rooms the app asked to join, in order.
  List<String> get joinRequests => [
        for (final packet in sentFor('join_room'))
          (packet.data as Map)['roomId'] as String,
      ];

  /// The token the handshake would carry now.
  String? get handshakeToken {
    String? token;
    final authorize = auth;
    if (authorize is Function) {
      authorize((Map data) => token = data['token'] as String?);
    }
    return token;
  }

  @override
  io.Socket connect() {
    connectCalls++;
    return this;
  }

  @override
  io.Socket disconnect() {
    disconnectCalls++;
    if (connected) {
      onclose('io client disconnect');
    }
    return this;
  }

  @override
  void emitWithAck(
    String event,
    dynamic data, {
    Function? ack,
    bool binary = false,
  }) {
    if (io.events.contains(event)) {
      // Reserved events ('connect', 'error', ...) are local.
      super.emitWithAck(event, data, ack: ack, binary: binary);
      return;
    }
    if (event == 'disconnecting') {
      // socket_io_client's own notice while closing, not the app's.
      return;
    }
    sent.add(SentPacket(event, data, ack, whileConnected: connected));
  }

  /// The server accepts the connection.
  void acceptConnection() => onconnect('fake-socket-id', null);

  /// The server refuses the handshake, e.g. `{'message': 'Account blocked:
  /// ...'}`.
  void refuseHandshake(Map<String, dynamic> payload) => emit('error', payload);

  /// The server sends [event].
  void serverEmit(String event, [Object? data]) {
    onevent({
      'data': [event, if (data != null) data],
    });
  }

  /// The server ends the connection, as on a ban, an expired token or a
  /// deploy.
  void serverDisconnect() => ondisconnect();

  /// The connection drops, as when the network goes away.
  void dropConnection() => onclose('transport close');
}
