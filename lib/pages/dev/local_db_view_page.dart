import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:kota_pf1_app/helpers/local_db.dart';
import 'package:kota_pf1_app/helpers/sync_service.dart';
import 'package:kota_pf1_app/constants/const_colors.dart';
import 'package:kota_pf1_app/constants/print_data.dart';

class LocalDbViewPage extends StatefulWidget {
  const LocalDbViewPage({super.key});

  @override
  State<LocalDbViewPage> createState() => _LocalDbViewPageState();
}

class _LocalDbViewPageState extends State<LocalDbViewPage> {
  late List<Map<String, dynamic>> rates;
  late Map<String, String> parkingTypeMap;
  late List<String> availableTypeIds;
  late List<Map<String, dynamic>> vehicleTypes;
  late List<Map<String, dynamic>> history;
  bool loading = false;

  // Sync progress
  bool _syncing = false;
  double _progress = 0.0;
  String _message = '';

  String _lastSyncText = '-';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    rates = LocalDb.getRates();
    parkingTypeMap = LocalDb.getParkingTypeMap();
    availableTypeIds = LocalDb.getAvailableParkingTypeIds();
    vehicleTypes = LocalDb.getVehicleTypes();
    history = LocalDb.getHistory();
    final last = LocalDb.getMeta('last_sync_at');
    _lastSyncText = last is String && last.isNotEmpty ? last : '-';
    setState(() => loading = false);
  }

  Future<void> _fetchAndReload() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      _progress = 0;
      _message = 'Starting...';
    });
    try {
      await SyncService().syncLookupData(onProgress: (p, msg) {
        if (!mounted) return;
        setState(() {
          _progress = p;
          _message = msg;
        });
      });
    } finally {
      await _load();
      if (mounted) {
        setState(() {
          _syncing = false;
          _progress = 0;
          _message = '';
        });
      }
    }
  }

  Widget _statsHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statChip('Rates', rates.length, Icons.list_alt),
                  _statChip('Types', vehicleTypes.length, Icons.directions_car),
                  _statChip('History', history.length, Icons.history),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Last Sync', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  Text(
                    _lastSyncText,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, int count, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ConstColors.themeColor),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text('$count', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child, {Widget? rawJson}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage, color: ConstColors.themeColor, size: 20),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            child,
            if (rawJson != null) ...[
              const SizedBox(height: 6),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Raw JSON', style: TextStyle(fontSize: 12)),
                children: [rawJson],
              ),
            ]
          ],
        ),
      ),
    );
  }

  String _pretty(Object data) {
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  Widget _ratesList() {
    if (rates.isEmpty) return const Text('No rates cached', style: TextStyle(fontSize: 12));
    final items = rates.take(10).toList();
    return Column(
      children: items.map((r) {
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('${r['vehicle_type_text']} • ${r['parking_type_text']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text('${r['duration_text']}  -  ${r['price']}', style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
    );
  }

  Widget _typesList() {
    if (vehicleTypes.isEmpty) return const Text('No vehicle types cached', style: TextStyle(fontSize: 12));
    final items = vehicleTypes.take(10).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((t) => Chip(label: Text('${t['vehicle_type']}'))).toList(),
    );
  }

  Widget _parkingTypesChips() {
    if (parkingTypeMap.isEmpty) return const Text('No parking types mapped', style: TextStyle(fontSize: 12));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: parkingTypeMap.entries
          .map((e) => Chip(label: Text('${e.key} - ${e.value}')))
          .toList(),
    );
  }

  Widget _historyList() {
    if (history.isEmpty) return const Text('No history cached', style: TextStyle(fontSize: 12));
    final items = history.take(15).toList();
    return Column(
      children: items.map((h) {
        final status = (h['status']?.toString() ?? '1') == '1' ? 'IN' : 'OUT';
        final co = (h['checkout_time'] ?? '').toString();
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(radius: 12, backgroundColor: status == 'IN' ? Colors.orange : Colors.green, child: Text(status == 'IN' ? 'I' : 'O', style: const TextStyle(color: Colors.white, fontSize: 12))),
          title: Text(h['vehicle_no']?.toString() ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text('In: ${h['checked_in'] ?? '-'}  •  Out: ${co.isEmpty ? '-' : co}', style: const TextStyle(fontSize: 12)),
          trailing: Text(h['parking_type_text']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: Colors.black54)),
        );
      }).toList(),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ConstColors.themeColor, ConstColors.themeColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: ConstColors.themeColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 200,
            height: 40,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(PrintData.appLogoWhite),
                fit: BoxFit.scaleDown,
              ),
            ),
          ),
          const Spacer(),
          _buildHeaderButton(Icons.refresh, () {
            if (!(loading || _syncing)) {
              _fetchAndReload();
            }
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: ConstColors.themeColor, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildHeader(),
                ),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _statsHeader(),
                              const SizedBox(height: 12),
                              _section('Parking Rates (${rates.length})', _ratesList(), rawJson: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Text(_pretty(rates), style: const TextStyle(fontSize: 12))))
,
                              _section('Parking Type Map', _parkingTypesChips(), rawJson: Text(_pretty(parkingTypeMap), style: const TextStyle(fontSize: 12))),
                              _section('Vehicle Types (${vehicleTypes.length})', _typesList(), rawJson: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Text(_pretty(vehicleTypes), style: const TextStyle(fontSize: 12)))),
                              _section('History (${history.length})', _historyList(), rawJson: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Text(_pretty(history), style: const TextStyle(fontSize: 12)))),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                ),
              ],
            ),
            if (_syncing)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.black.withOpacity(0.4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _message.isEmpty ? 'Syncing in progress...' : _message,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _progress.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(_progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (loading || _syncing) ? null : _fetchAndReload,
        backgroundColor: ConstColors.themeColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.cloud_download),
        label: const Text('Fetch Data'),
      ),
    );
  }
} 