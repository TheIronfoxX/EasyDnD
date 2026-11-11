import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/websocket_service.dart';

/// Diálogo accesible desde la AppBar de MainHudScreen para introducir la
/// IP del portátil-servidor y conectar/desconectar. No conoce nada de
/// CharacterProvider: solo habla con WebSocketService.
class ConnectionDialog extends StatefulWidget {
  final Color accent;

  const ConnectionDialog({super.key, required this.accent});

  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog> {
  late final TextEditingController _ipController;
  late bool _remote;

  @override
  void initState() {
    super.initState();
    final service = context.read<WebSocketService>();
    _ipController = TextEditingController(text: service.lastHost ?? '');
    _remote = service.isRemote;
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  void _connect(WebSocketService service) {
    final host = _ipController.text.trim();
    if (host.isEmpty) return;
    service.connect(host, remote: _remote);
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<WebSocketService>();
    final accent = widget.accent;
    final isConnecting = service.status == ConnectionStatus.connecting;
    // Si el accent es claro usamos texto oscuro, si es oscuro usamos texto claro.
    final onAccent =
        accent.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    return AlertDialog(
      title: Text(
        'Sincronización de Sala',
        style: TextStyle(color: accent, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Wifi local'),
                icon: Icon(Icons.wifi, size: 16),
              ),
              ButtonSegment(
                value: true,
                label: Text('Internet'),
                icon: Icon(Icons.public, size: 16),
              ),
            ],
            selected: {_remote},
            onSelectionChanged: isConnecting
                ? null
                : (selection) => setState(() => _remote = selection.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: accent.withOpacity(0.25),
              selectedForegroundColor: accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _remote
                ? 'Introduce el nombre del host de Tailscale (sin https, sin puerto).'
                : 'Introduce la IP local del portátil que ejecuta el servidor.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ipController,
            keyboardType: _remote
                ? TextInputType.url
                : const TextInputType.numberWithOptions(decimal: true),
            enabled: !isConnecting,
            decoration: InputDecoration(
              labelText: _remote ? 'Host remoto' : 'IP del servidor',
              hintText: _remote
                  ? 'portatilpedro-1.tail179c26.ts.net'
                  : '192.168.1.138',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _connect(service),
          ),
          const SizedBox(height: 14),
          _StatusRow(status: service.status, error: service.lastError),
        ],
      ),
      actions: [
        if (service.status == ConnectionStatus.connected ||
            service.status == ConnectionStatus.error)
          TextButton(
            onPressed: () => service.disconnect(),
            child: const Text('Desconectar'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        ElevatedButton(
          onPressed: isConnecting ? null : () => _connect(service),
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: onAccent,
          ),
          child: isConnecting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: onAccent,
                  ),
                )
              : const Text('Conectar'),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  final ConnectionStatus status;
  final String? error;

  const _StatusRow({required this.status, required this.error});

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String label;

    switch (status) {
      case ConnectionStatus.connected:
        color = Colors.greenAccent;
        label = 'Conectado';
        break;
      case ConnectionStatus.connecting:
        color = Colors.orangeAccent;
        label = 'Conectando...';
        break;
      case ConnectionStatus.error:
        color = Colors.redAccent;
        label = 'Sin conexión${error != null ? ' ($error)' : ''}';
        break;
      case ConnectionStatus.disconnected:
        color = Theme.of(context).colorScheme.onSurface.withOpacity(0.4);
        label = 'Desconectado';
        break;
    }

    return Row(
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}