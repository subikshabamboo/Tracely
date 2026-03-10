import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api_service.dart';
import '../../../core/theme.dart';

class TraceShareDialog extends StatefulWidget {
  final String traceId;

  const TraceShareDialog({super.key, required this.traceId});

  @override
  State<TraceShareDialog> createState() => _TraceShareDialogState();
}

class _TraceShareDialogState extends State<TraceShareDialog> {
  final ApiService _apiService = ApiService();
  bool _isPublic = true;
  DateTime? _expiresAt;
  String? _shareUrl;
  bool _isLoading = false;

  Future<void> _generateLink() async {
    setState(() => _isLoading = true);
    final result = await _apiService.createTraceShare(
      widget.traceId,
      _isPublic,
      expiresAt: _expiresAt,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.isSuccess) {
          final accessKey = result.data['access_key'];
          _shareUrl = 'http://localhost:8080/public/traces/$accessKey';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: TracelyTheme.surfaceColor,
      title: const Text('Share Trace', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_shareUrl == null) ...[
              SwitchListTile(
                title: const Text('Public Access', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Anyone with the link can view', style: TextStyle(color: Colors.white54)),
                value: _isPublic,
                onChanged: (val) => setState(() => _isPublic = val),
              ),
              ListTile(
                title: const Text('Expiration', style: TextStyle(color: Colors.white)),
                subtitle: Text(_expiresAt == null ? 'Never' : _expiresAt!.toLocal().toString(), style: const TextStyle(color: Colors.white54)),
                trailing: const Icon(Icons.calendar_today, color: Colors.orange),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) setState(() => _expiresAt = date);
                },
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_shareUrl!, 
                        style: const TextStyle(color: Colors.orange, fontFamily: 'monospace', fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white54),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _shareUrl!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied to clipboard')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('This link allows anyone to view the full trace waterfall and metadata.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        if (_shareUrl == null)
          ElevatedButton(
            onPressed: _isLoading ? null : _generateLink,
            child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Generate Link'),
          ),
      ],
    );
  }
}
