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

  @override
  void initState() {
    super.initState();
    final service = context.read<WebSocketService>();
    _ipController = TextEditingController(text: service.lastHost ?? '');
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  void _connect(WebSocketService service) {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;
    service.connect(ip);
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<WebSocketService>();
    final accent = widget.accent;
    final isConnecting = service.status == ConnectionStatus.connecting;

    return AlertDialog(
      title: Text(
        'Sincronización de Sala',
        style: TextStyle(color: accent, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Introduce la IP local del portátil que ejecuta el servidor.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ipController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            enabled: !isConnecting,
            decoration: const InputDecoration(
              labelText: 'IP del servidor',
              hintText: '192.168.1.138',
              border: OutlineInputBorder(),
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
          style: ElevatedButton.styleFrom(backgroundColor: accent),
          child: isConnecting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
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
