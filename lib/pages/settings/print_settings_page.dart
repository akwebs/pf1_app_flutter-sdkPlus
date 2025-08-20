import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kota_pf1_app/helpers/print_settings.dart';
import 'package:kota_pf1_app/constants/const_colors.dart';
import 'package:kota_pf1_app/constants/print_data.dart';
import 'package:kota_pf1_app/widgets/back_btn.dart';
import 'package:kota_pf1_app/helpers/sync_settings.dart';
import 'package:kota_pf1_app/helpers/sync_service.dart';

class PrintSettingsPage extends StatefulWidget {
  const PrintSettingsPage({super.key});

  @override
  State<PrintSettingsPage> createState() => _PrintSettingsPageState();
}

class _PrintSettingsPageState extends State<PrintSettingsPage> {
  PrintSettings? _settings;
  bool _saving = false;
  int _bgMinutes = SyncSettings.defaultMinutes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await PrintSettings.load();
    final m = await SyncSettings.loadMinutes();
    if (!mounted) return;
    setState(() { _settings = s; _bgMinutes = m; });
  }

  Future<void> _save(PrintSettings s) async {
    setState(() => _saving = true);
    await s.save();
    await SyncSettings.saveMinutes(_bgMinutes);
    await SyncService.configureBackgroundFetch();
    if (!mounted) return;
    setState(() => _saving = false);
  }

  Widget _buildSwitch(
      {required String title,
      required bool value,
      required ValueChanged<bool> onChanged,
      String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                  ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: (v) {
              onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndSave() async {
    final s = _settings;
    if (s == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Settings?'),
        content: const Text(
            'These settings will affect both print preview and actual print.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await _save(s);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    return Scaffold(
      body: s == null
          ? const Center(child: CupertinoActivityIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // Header like Check-In page
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            ConstColors.themeColor,
                            ConstColors.themeColor.withOpacity(0.8)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: ConstColors.themeColor.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        children: [
                          const BackBtn(),
                          const SizedBox(width: 8),
                          const Text(
                            'Print & Sync Settings',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Container(
                            width: 140,
                            height: 36,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                  image: AssetImage(PrintData.appLogoWhite),
                                  fit: BoxFit.scaleDown),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Header',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54)),
                              const SizedBox(height: 6),
                              _buildSwitch(
                                title: 'Organization Name',
                                value: s.includeOrgName,
                                onChanged: (v) => setState(() =>
                                    _settings = s.copyWith(includeOrgName: v)),
                              ),
                              _buildSwitch(
                                title: 'GST on Checkout',
                                subtitle: 'Shown only on checkout slips',
                                value: s.includeGstOnCheckout,
                                onChanged: (v) => setState(() => _settings =
                                    s.copyWith(includeGstOnCheckout: v)),
                              ),
                              const SizedBox(height: 12),
                              const Text('Times',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54)),
                              const SizedBox(height: 6),
                              _buildSwitch(
                                title: 'Check-In Time',
                                value: s.includeCheckInTime,
                                onChanged: (v) => setState(() => _settings =
                                    s.copyWith(includeCheckInTime: v)),
                              ),
                              _buildSwitch(
                                title: 'Checkout Time',
                                subtitle: 'Shown only on checkout slips',
                                value: s.includeCheckoutTime,
                                onChanged: (v) => setState(() => _settings =
                                    s.copyWith(includeCheckoutTime: v)),
                              ),
                              const SizedBox(height: 12),
                              const Text('Vehicle',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54)),
                              const SizedBox(height: 6),
                              _buildSwitch(
                                title: 'Vehicle Number',
                                value: s.includeVehicleNo,
                                onChanged: (v) => setState(() => _settings =
                                    s.copyWith(includeVehicleNo: v)),
                              ),
                              _buildSwitch(
                                title: 'Parking Type',
                                value: s.includeParkingType,
                                onChanged: (v) => setState(() => _settings =
                                    s.copyWith(includeParkingType: v)),
                              ),
                              _buildSwitch(
                                title: 'Vehicle Type',
                                value: s.includeVehicleType,
                                onChanged: (v) => setState(() => _settings =
                                    s.copyWith(includeVehicleType: v)),
                              ),
                              _buildSwitch(
                                title: 'Token No',
                                value: s.includeTokenNo,
                                onChanged: (v) => setState(() =>
                                    _settings = s.copyWith(includeTokenNo: v)),
                              ),
                              _buildSwitch(
                                title: 'Helmet (Two Wheeler)',
                                value: s.includeHelmet,
                                onChanged: (v) => setState(() =>
                                    _settings = s.copyWith(includeHelmet: v)),
                              ),
                              const SizedBox(height: 12),
                              const Text('Rates & Footers',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54)),
                              const SizedBox(height: 6),
                              _buildSwitch(
                                title: 'Parking Rates (Check-In/Reprint)',
                                value: s.includeParkingRates,
                                onChanged: (v) => setState(() => _settings =
                                    s.copyWith(includeParkingRates: v)),
                              ),
                              _buildSwitch(
                                title: 'Receipt Lost Notice',
                                value: s.includeReceiptLost,
                                onChanged: (v) => setState(() => _settings =
                                    s.copyWith(includeReceiptLost: v)),
                              ),
                              _buildSwitch(
                                title: 'Thank You',
                                value: s.includeThankYou,
                                onChanged: (v) => setState(() =>
                                    _settings = s.copyWith(includeThankYou: v)),
                              ),
                              _buildSwitch(
                                title: 'Railway Help Line (Checkout)',
                                subtitle: 'Shown only on checkout slips',
                                value: s.includeRailwayHelpLine,
                                onChanged: (v) => setState(() => _settings =
                                    s.copyWith(includeRailwayHelpLine: v)),
                              ),
                              const SizedBox(height: 12),
                              const Text('QR & Layout',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54)),
                              const SizedBox(height: 6),
                              _buildSwitch(
                                title: 'QR on Check-In',
                                value: s.includeQrOnCheckIn,
                                onChanged: (v) => setState(() => _settings =
                                    s.copyWith(includeQrOnCheckIn: v)),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text('Extra Feed Lines (Check-In)',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  CupertinoButton(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    onPressed: s.extraFeedCheckIn > 0
                                        ? () => setState(() => _settings =
                                            s.copyWith(
                                                extraFeedCheckIn:
                                                    s.extraFeedCheckIn - 1))
                                        : null,
                                    child: const Icon(Icons.remove_circle),
                                  ),
                                  Text('${s.extraFeedCheckIn}',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  CupertinoButton(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    onPressed: () => setState(() => _settings =
                                        s.copyWith(
                                            extraFeedCheckIn:
                                                s.extraFeedCheckIn + 1)),
                                    child: const Icon(Icons.add_circle),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text('Background Sync',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text('Sync every',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  DropdownButton<int>(
                                    value: _bgMinutes,
                                    onChanged: (v) {
                                      if (v == null) return;
                                      setState(() => _bgMinutes = v);
                                    },
                                    items: const [10, 20, 30, 60]
                                        .map((m) => DropdownMenuItem<int>(
                                              value: m,
                                              child: Text('$m min'),
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Syncs rates, parking types and recent history in the background. Requires network.',
                                style: TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: _buildBottomSaveBar(_saving, _confirmAndSave),
    );
  }
}

Widget _buildBottomSaveBar(bool _saving, Function() _confirmAndSave) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 30),
    child: Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: _saving ? null : _confirmAndSave,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              if (_saving)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child:
                      CupertinoActivityIndicator(),
                )
              else ...[
                Icon(Icons.save,
                    color: ConstColors.themeColor,
                    size: 24),
                const SizedBox(width: 6),
                Text(
                  'Save Settings',
                  style: TextStyle(
                    color: ConstColors.themeColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}