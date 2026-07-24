import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

/// Estado de la conexión con el servidor local. La UI (ConnectionDialog,
/// el botón de la AppBar) escucha este enum a través de ChangeNotifier
/// para pintar un indicador de estado sin lógica propia de red.
enum ConnectionStatus { disconnected, connecting, connected, error }

const String _kPlayerIdPrefsKey = 'ws_player_id';

/// Gestiona la conexión WebSocket al servidor local (portátil) que corre
/// server.dart. Responsabilidades:
///  - Conectar/desconectar a `ws://<ip>:8080`.
///  - Identificarse ante el servidor con un `playerId` persistente (no
///    cambia entre reconexiones ni entre arranques de la app), para que
///    el servidor pueda reconocer "soy el mismo jugador de antes" y no
///    duplique su personaje ni dispare eventos de join/leave de más.
///  - Reconexión automática con backoff simple si la conexión se cae de
///    forma inesperada (no si el usuario desconecta a propósito), y
///    también al volver la app a primer plano tras estar en background
///    o con la pantalla apagada.
///  - Decodificar mensajes JSON entrantes y exponerlos como stream de
///    `Map<String, dynamic>` (para que CharacterProvider los consuma sin
///    saber nada de WebSockets).
///  - Codificar y enviar acciones salientes.
///
/// Se registra como ChangeNotifierProvider en main.dart, al mismo nivel
/// que CharacterProvider, para que cualquier widget pueda hacer
/// `context.watch<WebSocketService>()` y mostrar el estado de conexión.
class WebSocketService extends ChangeNotifier with WidgetsBindingObserver {
  static const int _port = 8080;
  static const int _maxReconnectAttempts = 5;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionStatus get status => _status;

  String? _lastHost;
  String? get lastHost => _lastHost;

  String? _lastError;
  String? get lastError => _lastError;

  int _reconnectAttempts = 0;
  bool _manuallyDisconnected = false;
  bool _lifecycleObserverAttached = false;

  String? _playerId;
  String? get playerId => _playerId;

  final _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Mensajes ya decodificados de JSON, listos para que
  /// CharacterProvider.applyRemoteAction() los procese.
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  /// Recupera (o genera y guarda) el `playerId` persistente de este
  /// dispositivo. Debe llamarse antes de la primera conexión; `connect`
  /// ya se asegura de ello internamente.
  Future<String> _ensurePlayerId() async {
    if (_playerId != null) return _playerId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kPlayerIdPrefsKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_kPlayerIdPrefsKey, id);
    }
    _playerId = id;
    return id;
  }

  /// Empieza a escuchar el ciclo de vida de la app (foreground/background)
  /// para reconectar automáticamente cuando el usuario vuelve a la app,
  /// aunque la pantalla se haya apagado o haya pasado a background
  /// mientras esperaba su turno. Llamar una vez, por ejemplo en main.dart
  /// justo después de crear el provider.
  void startObservingLifecycle() {
    if (_lifecycleObserverAttached) return;
    _lifecycleObserverAttached = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Al volver a primer plano, si teníamos un host y no estamos ya
        // conectados (y el usuario no desconectó a propósito), reintenta
        // de inmediato en vez de esperar al backoff.
        if (_lastHost != null &&
            _status != ConnectionStatus.connected &&
            _status != ConnectionStatus.connecting &&
            !_manuallyDisconnected) {
          _reconnectTimer?.cancel();
          _reconnectAttempts = 0;
          _attemptConnect();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // No forzamos desconexión: dejamos que el sistema operativo corte
        // el socket si le da la gana. Cancelamos el timer de reconexión
        // en curso para no gastar intentos mientras no hay nadie mirando;
        // al volver a resumed se relanza limpio desde cero.
        _reconnectTimer?.cancel();
        break;
      default:
        break;
    }
  }

  /// Conecta a `ws://<host>:8080`. Si ya había una conexión previa, la
  /// cierra primero. Guarda `host` para poder reintentar si la conexión
  /// se cae más adelante.
  Future<void> connect(String host) async {
    _manuallyDisconnected = false;
    _lastHost = host;
    _reconnectAttempts = 0;
    await _ensurePlayerId();
    await _closeChannel();
    await _attemptConnect();
  }

  Future<void> _attemptConnect() async {
    final host = _lastHost;
    if (host == null) return;

    _setStatus(ConnectionStatus.connecting);

    try {
      final id = await _ensurePlayerId();
      final uri = Uri.parse('ws://$host:$_port');
      final channel = WebSocketChannel.connect(uri);
      // `ready` completa cuando el handshake termina, o lanza si falla
      // (IP incorrecta, servidor no arrancado, fuera de la red, etc.).
      await channel.ready;

      // Primer mensaje obligatorio: nos identificamos ante el servidor
      // con nuestro playerId persistente, para que reconozca que somos
      // el mismo jugador de antes y no duplique el personaje.
      channel.sink.add(jsonEncode({'type': 'hello', 'playerId': id}));

      _channel = channel;
      _lastError = null;
      _reconnectAttempts = 0;
      _setStatus(ConnectionStatus.connected);

      _subscription = channel.stream.listen(
        _handleIncoming,
        onDone: () => _handleDisconnect(),
        onError: (error) => _handleDisconnect(error: error),
        cancelOnError: true,
      );
    } catch (e) {
      _lastError = e.toString();
      _channel = null;
      _setStatus(ConnectionStatus.error);
      _scheduleReconnect();
    }
  }

  void _handleIncoming(dynamic raw) {
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is Map<String, dynamic>) {
        _messageController.add(decoded);
      }
    } catch (e) {
      // Un mensaje corrupto o ajeno no debe tumbar la conexión: se
      // descarta y se sigue escuchando.
      debugPrint('WebSocketService: mensaje entrante inválido ($e)');
    }
  }

  /// Envía una acción como JSON al servidor, que la retransmitirá al
  /// resto de clientes. Si no hay conexión activa, no hace nada (no
  /// lanza excepción: el modo "sin conexión" debe ser seguro).
  void send(Map<String, dynamic> action) {
    final channel = _channel;
    if (channel == null || _status != ConnectionStatus.connected) return;
    try {
      channel.sink.add(jsonEncode(action));
    } catch (e) {
      debugPrint('WebSocketService: fallo al enviar acción ($e)');
      return;
    }

    // El servidor (ver EmbeddedClientManager._handleMessage) retransmite
    // esta acción "a todos menos al emisor" (exclude: channel) — nunca
    // nos la devuelve a nosotros mismos. Sin este eco local, cualquier
    // servicio que escuche `messages` (CharacterProvider,
    // PartyRosterService, etc.) nunca se enteraría de nuestras propias
    // acciones, y por ejemplo nuestro propio jugador jamás aparecería en
    // su propio roster de PartyTab. Replicamos aquí el mismo `id` que el
    // servidor le añadiría (mapMsg['id'] = playerId) para que el eco sea
    // indistinguible de un mensaje entrante real. 'kick' se excluye
    // porque el servidor tampoco lo retransmite (lo procesa y corta).
    if (action['type'] != 'kick' && _playerId != null) {
      final echoed = Map<String, dynamic>.from(action)..['id'] = _playerId;
      _messageController.add(echoed);
    }
  }

  void _handleDisconnect({Object? error}) {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    if (error != null) _lastError = error.toString();

    if (_manuallyDisconnected) {
      _setStatus(ConnectionStatus.disconnected);
      return;
    }

    _setStatus(ConnectionStatus.error);
    _scheduleReconnect();
  }

  /// Reconexión básica con backoff lineal (2s, 4s, 6s...) hasta
  /// `_maxReconnectAttempts`. Suficiente para un servidor local en la
  /// misma Wi-Fi: no hace falta backoff exponencial ni jitter.
  void _scheduleReconnect() {
    if (_manuallyDisconnected || _lastHost == null) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) return;

    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_manuallyDisconnected) _attemptConnect();
    });
  }

  /// Desconexión explícita pedida por el usuario (botón "Desconectar").
  /// A diferencia de una caída de red, esta NO dispara reconexión
  /// automática.
  void disconnect() {
    _manuallyDisconnected = true;
    _reconnectTimer?.cancel();
    _closeChannel();
    _setStatus(ConnectionStatus.disconnected);
  }

  Future<void> _closeChannel() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close(ws_status.normalClosure);
    _channel = null;
  }

  void _setStatus(ConnectionStatus s) {
    _status = s;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_lifecycleObserverAttached) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _messageController.close();
    super.dispose();
  }
}