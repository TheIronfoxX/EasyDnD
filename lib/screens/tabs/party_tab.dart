import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/party_roster_service.dart';
import '../../services/websocket_service.dart';
import '../../theme/app_theme_extension.dart';

/// Resplandor dorado que resalta a quien tiene el turno activo — el
/// mismo lenguaje visual que usa la app de Mesa del DM, para que el
/// jugador reconozca el patrón de un vistazo aunque cambie su acento
/// personal del HUD.
const Color _kTurnAccent = Color(0xFFFFD166);

/// Pestaña "Party": quién más está conectado a la mesa y a quién le
/// toca. A propósito NO muestra vida ni CA de nadie más que la propia
/// (eso ya vive en Stats / Mi Turno) — PartyRosterService ni siquiera
/// guarda esos datos de los demás, así que no hay forma de que se
/// cuelen aquí por error.
class PartyTab extends StatelessWidget {
  const PartyTab({super.key});

  @override
  Widget build(BuildContext context) {
    final wsStatus = context.watch<WebSocketService>().status;

    if (wsStatus != ConnectionStatus.connected) {
      return _NotConnectedPlaceholder(status: wsStatus);
    }

    final roster = context.watch<PartyRosterService>();
    final members = roster.members;
    final selfId = roster.selfId;

    // Jugadores primero (por nombre), NPCs al final — la lista de
    // "quién hay en la mesa" es más útil ordenada así que por orden de
    // llegada.
    final sorted = [...members]..sort((a, b) {
        if (a.isNpc != b.isNpc) return a.isNpc ? 1 : -1;
        final an = a.characterName ?? '';
        final bn = b.characterName ?? '';
        return an.compareTo(bn);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _RoundHeader(round: roster.round, inCombat: roster.activeTurnId != null),
        const SizedBox(height: 14),
        if (sorted.isEmpty)
          Text(
            'Todavía no hay nadie más en la mesa.',
            style: GoogleFonts.inter(color: context.appColors.textSecondary, fontSize: 13),
          )
        else
          ...sorted.map((m) {
            final turnIdx = roster.turnOrder.indexOf(m.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PartyMemberCard(
                member: m,
                isSelf: m.id == selfId,
                isActiveTurn: roster.activeTurnId == m.id,
                turnPosition: turnIdx == -1 ? null : turnIdx + 1,
              ),
            );
          }),
      ],
    );
  }
}

class _NotConnectedPlaceholder extends StatelessWidget {
  final ConnectionStatus status;
  const _NotConnectedPlaceholder({required this.status});

  @override
  Widget build(BuildContext context) {
    final connecting = status == ConnectionStatus.connecting;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              connecting ? Icons.wifi_tethering : Icons.wifi_off,
              size: 40,
              color: context.appColors.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              connecting
                  ? 'Conectando con la mesa…'
                  : 'No estás conectado a ninguna mesa todavía.\nUsa el botón de sincronización de la barra superior.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: context.appColors.textSecondary, fontSize: 13.5, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundHeader extends StatelessWidget {
  final int round;
  final bool inCombat;
  const _RoundHeader({required this.round, required this.inCombat});

  @override
  Widget build(BuildContext context) {
    if (!inCombat) {
      return Row(
        children: [
          Icon(Icons.groups_outlined, color: context.appColors.textSecondary, size: 18),
          const SizedBox(width: 8),
          Text(
            'FUERA DE COMBATE',
            style: GoogleFonts.inter(
              color: context.appColors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              letterSpacing: 0.5,
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Icon(Icons.local_fire_department, color: _kTurnAccent, size: 18),
        const SizedBox(width: 8),
        Text(
          'RONDA $round',
          style: GoogleFonts.inter(
            color: _kTurnAccent,
            fontWeight: FontWeight.w800,
            fontSize: 13.5,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _PartyMemberCard extends StatelessWidget {
  final PartyMember member;
  final bool isSelf;
  final bool isActiveTurn;
  final int? turnPosition;

  const _PartyMemberCard({
    required this.member,
    required this.isSelf,
    required this.isActiveTurn,
    required this.turnPosition,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isActiveTurn ? _kTurnAccent : Theme.of(context).colorScheme.onSurface.withOpacity(0.06);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          (isActiveTurn ? _kTurnAccent : Colors.white).withOpacity(isActiveTurn ? 0.07 : 0.03),
          context.appColors.surface,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isActiveTurn ? 1.4 : 1),
        boxShadow: isActiveTurn
            ? [BoxShadow(color: _kTurnAccent.withOpacity(0.22), blurRadius: 18, spreadRadius: -6)]
            : null,
      ),
      child: Row(
        children: [
          if (turnPosition != null) ...[
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActiveTurn ? _kTurnAccent : context.appColors.textSecondary.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$turnPosition',
                style: GoogleFonts.inter(color: Colors.black, fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Icon(
            member.isNpc ? Icons.pest_control_outlined : Icons.person_outline,
            color: isActiveTurn ? _kTurnAccent : context.appColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.characterName ?? (member.isNpc ? 'NPC' : 'Jugador'),
                        style: GoogleFonts.inter(
                          color: isActiveTurn ? _kTurnAccent : context.appColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kTurnAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'TÚ',
                          style: GoogleFonts.inter(color: _kTurnAccent, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
                if (member.level != null || member.initiativeTotal != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (member.level != null) 'Nivel ${member.level}',
                      if (member.initiativeTotal != null) 'Iniciativa ${member.initiativeTotal}',
                    ].join('  ·  '),
                    style: GoogleFonts.inter(color: context.appColors.textSecondary, fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
          if (isActiveTurn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _kTurnAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'SU TURNO',
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}