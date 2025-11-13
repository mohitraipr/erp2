import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/lot_models.dart';
import '../../services/api_client.dart';
import '../../services/api_service.dart';
import '../../state/auth_controller.dart';
import '../../utils/ui_helpers.dart';

class LotDetailScreen extends StatefulWidget {
  final int lotId;
  final LotSummary? summary;

  const LotDetailScreen({super.key, required this.lotId, this.summary});

  @override
  State<LotDetailScreen> createState() => _LotDetailScreenState();
}

class _LotDetailScreenState extends State<LotDetailScreen> {
  LotDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<ApiService>();
    try {
      final detail = await api.fetchLotDetail(widget.lotId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = errorMessage(error);
        });
      }
      if (isUnauthorizedError(error)) {
        context.read<AuthController>().handleUnauthorized();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    return Scaffold(
      appBar: AppBar(
        title: Text(summary?.lotNumber ?? 'Lot ${widget.lotId}'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final detail = _detail;
    if (detail == null) {
      return const Center(child: Text('No detail available.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _InfoChip(label: 'Lot', value: detail.lotNumber),
              _InfoChip(label: 'SKU', value: detail.sku),
              _InfoChip(label: 'Fabric', value: detail.fabricType),
              if (detail.totalPieces != null)
                _InfoChip(label: 'Pieces', value: '${detail.totalPieces}'),
            ],
          ),
          const SizedBox(height: 24),
          Text('Sizes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...detail.sizes.map(
            (size) => ListTile(
              title: Text(size.sizeLabel),
              subtitle: Text('Patterns: ${size.patternCount}'),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (size.totalPieces != null) Text('Pieces: ${size.totalPieces}'),
                  if (size.bundleCount != null) Text('Bundles: ${size.bundleCount}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (detail.bundles.isNotEmpty)
            ExpansionTile(
              title: const Text('Bundles'),
              children: detail.bundles
                  .map(
                    (bundle) => ListTile(
                      title: Text(bundle.bundleCode),
                      subtitle: Text('Size: ${bundle.sizeLabel}'),
                      trailing: bundle.pieces != null
                          ? Text('${bundle.pieces} pcs')
                          : null,
                    ),
                  )
                  .toList(),
            ),
          if (detail.pieces.isNotEmpty)
            ExpansionTile(
              title: const Text('Pieces'),
              children: detail.pieces
                  .map(
                    (piece) => ListTile(
                      title: Text(piece.pieceCode),
                      subtitle: Text('Bundle: ${piece.bundleCode}'),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 24),
          if (detail.downloads.bundleCodes != null || detail.downloads.pieceCodes != null)
            Row(
              children: [
                if (detail.downloads.bundleCodes != null)
                  FilledButton.icon(
                    onPressed: () => _openDownload(detail.downloads.bundleCodes!),
                    icon: const Icon(Icons.download),
                    label: const Text('Bundle CSV'),
                  ),
                const SizedBox(width: 12),
                if (detail.downloads.pieceCodes != null)
                  OutlinedButton.icon(
                    onPressed: () => _openDownload(detail.downloads.pieceCodes!),
                    icon: const Icon(Icons.download),
                    label: const Text('Piece CSV'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _openDownload(String path) async {
    final api = context.read<ApiService>();
    final uri = path.startsWith('http') ? Uri.parse(path) : api.resolveDownloadUrl(path);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      showErrorSnackBar(context, ApiException('Unable to open download link.'));
    }
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
