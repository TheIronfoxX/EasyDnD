import 'dart:async';

import 'package:flutter/foundation.dart';

import 'websocket_service.dart';

/// Entrada "pública" de un jugador o NPC conectado a la mesa, tal y
/// como la ve el HUD de un jugador cualquiera. A propósito NO tiene
/// ningún campo de vida (hpCurrent/hpMax) ni de CA: solo lo necesario
/// para saber quién más está en la mesa y a quién le toca. Que el
/// campo ni exista es intencional — así no hay ningún camino, ni
/// siquiera por error de copiar/pegar en el futuro, para que la vida
/// de un compañero acabe pintada aquí.
class PartyMember {
  final String id;
  String? characterName;
  int? level;
  int? initiativeRoll;
  int? initiativeMod;
  bool isNpc;

  PartyMember({
    required this.id,
    this.characterName,
    this.level,
    this.initiativeRoll,
    this.initiativeMod,
    this.isNpc = false,
  });

  /// Iniciativa total = tirada + bonificador. Null si aún no se ha tirado.
  int? get initiativeTotal {
    if (initiativeRoll == null) return null;
    return initiativeRoll! + (initiativeMod ?? 0);
  }
}

/// Escucha el mismo stream de mensajes que ya usa CharacterProvider
/// (WebSocketService.messages) para construir, en paralelo y sin
/// pisarse con él, un roster de "quién hay en la mesa y a quién le
/// toca". El servidor retransmite a todos los conectados los mismos
/// eventos de presencia/iniciativa/turno que usa la app de Mesa del DM
/// (ver party_ws_service.dart de esa app); este servicio procesa esos
/// mismos eventos pero se queda solo con nombre/nivel/iniciativa/turno,
/// descartando cualquier campo de vida que pueda venir en el mensaje
/// (p.ej. hp_current/hp_max dentro de un syncCharacter).
///
/// Se registra con un ChangeNotifierProvider.value en MainHudScreen,
/// igual que el resto de servicios, para que PartyTab pueda hacer
/// `context.watch<PartyRosterService>()`.
class PartyRosterService extends ChangeNotifier {
  final WebSocketService _wsService;
  StreamSubscription<Map<String, dynamic>>? _sub;

  final Map<String, PartyMember> _members = {};

  /// Copia inmutable para la UI — evita que un widget mute el mapa
  /// interno por accidente al iterarlo.
  List<PartyMember> get members => _members.values.toList(growable: false);

  /// Orden de turnos tal y como lo fija el DM (ver turnUpdate), de
  /// mayor a menor iniciativa.
  List<String> turnOrder = [];

  /// Índice dentro de [turnOrder] de quién tiene el turno ahora mismo.
  /// -1 si no hay combate en marcha.
  int currentTurnIndex = -1;

  /// Ronda de combate actual.
  int round = 1;

  /// Id de quien tiene el turno activo ahora mismo, o null si no hay
  /// rastreador de turnos en marcha.
  String? get activeTurnId {
    if (currentTurnIndex < 0 || currentTurnIndex >= turnOrder.length) return null;
    return turnOrder[currentTurnIndex];
  }

  /// El playerId persistente de este dispositivo (ver
  /// WebSocketService._ensurePlayerId) — así la UI puede marcar "TÚ"
  /// sin que este servicio tenga que duplicar esa lógica.
  String? get selfId => _wsService.playerId;

  PartyRosterService(this._wsService) {
    _sub = _wsService.messages.listen(_handleMessage);
    _wsService.addListener(_onConnectionChanged);
  }

  void _onConnectionChanged() {
    // Al perder la conexión (o mientras se reconecta) el roster de la
    // sesión anterior ya no es de fiar: se limpia y se reconstruye
    // desde cero con el próximo 'roster' que mande el servidor al
    // reconectar.
    if (_wsService.status != ConnectionStatus.connected) {
      _clear();
    }
  }

  void _clear() {
    if (_members.isEmpty && turnOrder.isEmpty && currentTurnIndex == -1 && round == 1) {
      return;
    }
    _members.clear();
    turnOrder = [];
    currentTurnIndex = -1;
    round = 1;
    notifyListeners();
  }

  PartyMember _ensure(String id) => _members.putIfAbsent(id, () => PartyMember(id: id));

  void _handleMessage(Map<String, dynamic> msg) {
    final event = (msg['event'] as String?) ?? (msg['type'] as String?);
    final id = msg['id'] as String?;

    // 1. Presencia: altas/bajas de jugadores conectados a la mesa.
    if (msg['__presence__'] == true) {
      if (id == null) return;
      switch (event) {
        case 'roster':
          final existing = (msg['existing'] as List?)?.whereType<String>() ?? const <String>[];
          for (final otherId in existing) {
            _ensure(otherId);
          }
          break;
        case 'join':
          _ensure(id);
          break;
        case 'leave':
          _members.remove(id);
          _pruneTurnOrder(id);
          break;
      }
      notifyListeners();
      return;
    }

    switch (event) {
      // 2. Personaje sincronizado por otro jugador: solo nos quedamos
      //    con nombre/nivel/iniciativa. hp_current/hp_max, si vienen,
      //    se ignoran a propósito.
      case 'syncCharacter':
        if (id == null) return;
        final characterData = (msg['data'] as Map<String, dynamic>?) ??
            (msg['character'] as Map<String, dynamic>?) ??
            msg;
        final basicInfo = characterData['basic_info'] as Map<String, dynamic>?;
        final member = _ensure(id);
        member.characterName = basicInfo?['name'] as String? ?? member.characterName;

        int? level = (basicInfo?['level'] as num?)?.toInt();
        final characterClass = basicInfo?['characterClass'] as String?;
        if ((level == null || level == 0) && characterClass != null) {
          final match = RegExp(r'(\d+)').firstMatch(characterClass);
          if (match != null) level = int.tryParse(match.group(1)!);
        }
        member.level = level ?? member.level;

        final stats = characterData['stats'] as Map<String, dynamic>?;
        final dexStat = stats?['dex'] as Map<String, dynamic>?;
        final explicitInitiative = (basicInfo?['initiative'] as num?)?.toInt();
        member.initiativeMod =
            explicitInitiative ?? (dexStat?['mod'] as num?)?.toInt() ?? member.initiativeMod;
        notifyListeners();
        break;

      // 3. NPC metido por el DM — mismo formato de ficha que
      //    syncCharacter (basic_info, stats...), así que se parsea
      //    igual: nombre y nivel, nunca su vida.
      case 'npcSync':
        if (id == null) return;
        final npcData = (msg['data'] as Map<String, dynamic>?) ??
            (msg['character'] as Map<String, dynamic>?) ??
            (msg['npc'] as Map<String, dynamic>?) ??
            msg;
        final npcBasicInfo = npcData['basic_info'] as Map<String, dynamic>?;
        final member = _ensure(id);
        member.isNpc = true;
        member.characterName = npcBasicInfo?['name'] as String? ?? member.characterName;

        int? npcLevel = (npcBasicInfo?['level'] as num?)?.toInt();
        final npcClass = npcBasicInfo?['characterClass'] as String?;
        if ((npcLevel == null || npcLevel == 0) && npcClass != null) {
          final match = RegExp(r'(\d+)').firstMatch(npcClass);
          if (match != null) npcLevel = int.tryParse(match.group(1)!);
        }
        member.level = npcLevel ?? member.level;
        notifyListeners();
        break;

      case 'npcRemove':
        final npcId = msg['npcId'] as String?;
        if (npcId != null) {
          _members.remove(npcId);
          _pruneTurnOrder(npcId);
          notifyListeners();
        }
        break;

      // 4. Iniciativa: el DM tira/borra los dados.
      case 'initiativeUpdate':
        final rolls = msg['rolls'] as Map<String, dynamic>?;
        if (rolls == null) return;
        rolls.forEach((rollId, value) {
          _members[rollId]?.initiativeRoll = (value as num?)?.toInt();
        });
        notifyListeners();
        break;

      case 'initiativeClear':
        for (final m in _members.values) {
          m.initiativeRoll = null;
        }
        turnOrder = [];
        currentTurnIndex = -1;
        round = 1;
        notifyListeners();
        break;

      // 5. Rastreador de turnos: quién tiene el turno y en qué ronda.
      case 'turnUpdate':
        turnOrder = (msg['order'] as List?)?.whereType<String>().toList() ?? <String>[];
        currentTurnIndex = (msg['index'] as num?)?.toInt() ?? -1;
        round = (msg['round'] as num?)?.toInt() ?? 1;
        notifyListeners();
        break;
    }
  }

  /// Quita un id del rastreador de turnos si ya no está en la mesa
  /// (expulsado o NPC eliminado), reajustando el turno activo.
  void _pruneTurnOrder(String id) {
    if (!turnOrder.contains(id)) return;
    final removedIdx = turnOrder.indexOf(id);
    turnOrder = List<String>.from(turnOrder)..remove(id);
    if (turnOrder.isEmpty) {
      currentTurnIndex = -1;
    } else if (removedIdx <= currentTurnIndex) {
      currentTurnIndex = (currentTurnIndex - 1).clamp(0, turnOrder.length - 1);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _wsService.removeListener(_onConnectionChanged);
    super.dispose();
  }
}