import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kota_pf1_app/constants/print_data.dart';
import 'package:provider/provider.dart';
import 'package:kota_pf1_app/constants/const_colors.dart';
import 'package:kota_pf1_app/constants/str_constants.dart';
import 'package:kota_pf1_app/controllers/loader_controller.dart';
import 'package:kota_pf1_app/helpers/api_helper.dart';
import 'package:kota_pf1_app/helpers/pref_helper.dart';
import 'package:kota_pf1_app/helpers/route_helper.dart';
import 'package:kota_pf1_app/helpers/toast_helper.dart';
import 'package:kota_pf1_app/pages/check_in/check_in_page.dart';
import 'package:kota_pf1_app/pages/check_out/check_out_page.dart';
import 'package:kota_pf1_app/pages/check_price/check_price_page.dart';
import 'package:kota_pf1_app/pages/edit_list/edit_list_page.dart';
import 'package:kota_pf1_app/pages/home/widgets/home_action_btn.dart';
import 'package:kota_pf1_app/pages/home/widgets/home_pie_chart.dart';
import 'package:kota_pf1_app/pages/login/login_page.dart';
import 'package:kota_pf1_app/pages/parking_rates/parking_rates_page.dart';
import 'package:kota_pf1_app/pages/reprint/reprint.dart';
import 'package:kota_pf1_app/providers/home_provider.dart';
import 'package:kota_pf1_app/providers/parking_rates_provider.dart';
import 'package:kota_pf1_app/helpers/local_db.dart';
import 'package:kota_pf1_app/pages/dev/local_db_view_page.dart';
import 'package:kota_pf1_app/pages/settings/print_settings_page.dart';
import 'package:kota_pf1_app/helpers/sync_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    Future.delayed(Duration.zero, () async {
      if (!mounted) return;
      context.read<HomeProvider>().loadData(context);
      // Ensure rates and parking type data are cached locally (cache-first)
      context.read<ParkingRatesProvider>().ensureCachedRates(context);
      // Prompt manual sync if last sync older than 30 minutes
      try {
        final last = LocalDb.getMeta('last_sync_at');
        if (last is String && last.isNotEmpty) {
          final lastDt = DateTime.tryParse(last);
          if (lastDt != null) {
            final diff = DateTime.now().difference(lastDt);
            if (diff.inMinutes >= 30) {
              if (!mounted) return;
              _showManualSyncPrompt(diff);
            }
          }
        }
      } catch (_) {}
    });
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set status bar to transparent with light icons
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.dark,
      ),
    );
  }

  Future<void> _refreshData() async {
    await context.read<HomeProvider>().loadData(context);
  }

  Future<void> _handleLogout() async {
    final savedEnv = await PrefHelper.getString('env');
    // Clear preferences and local DB
    await LocalDb.clearAll();
    await PrefHelper.clearAll();
    if (savedEnv.isNotEmpty) {
      await PrefHelper.setString('env', savedEnv);
      await PrintData.init();
    }
    if (!mounted) return;
    RouteHelper.replace(context, () => const LoginPage());
  }

  Future<void> _showManualSyncPrompt(Duration since) async {
    final mins = since.inMinutes;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Text('Data Sync Recommended'),
          content: Text('Last sync was $mins minutes ago. Would you like to sync now?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sync Now')),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _runManualSync();
    }
  }

  Future<void> _runManualSync() async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        double progress = 0;
        String message = 'Starting...';
        // Kick off sync and update local state via setState in StatefulBuilder
        SyncService().syncLookupData(onProgress: (p, m) {
          progress = p;
          message = m;
          (ctx as Element).markNeedsBuild();
        }).then((_) {
          if (Navigator.canPop(ctx)) Navigator.pop(ctx);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync completed')));
            context.read<ParkingRatesProvider>().ensureCachedRates(context);
            context.read<HomeProvider>().loadData(context);
          }
        }).catchError((_) {
          if (Navigator.canPop(ctx)) Navigator.pop(ctx);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync failed')));
          }
        });
        return StatefulBuilder(builder: (c, setState) {
          return AlertDialog(
            title: const Text('Syncing...'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress == 0 ? null : progress),
                const SizedBox(height: 12),
                Text(message),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading = context.watch<HomeProvider>().isLoading;

    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(color: ConstColors.themeColor),
              )
            : RefreshIndicator(
                onRefresh: _refreshData,
                color: ConstColors.themeColor,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with logo and actions
                      _buildHeader(),
                      const SizedBox(height: 20),

                      // Current Status Section
                      // _buildSectionTitle('Current Status'),
                      // Row(
                      //   children: [
                      //     Expanded(
                      //       child: _buildStatCard(
                      //         'Currently Parked',
                      //         context.watch<HomeProvider>().data['occupied']?.toString() ?? '0',
                      //         Icons.local_parking,
                      //         ConstColors.themeColor,
                      //       ),
                      //     ),
                      //     const SizedBox(width: 16),
                      //     Expanded(
                      //       child: _buildStatCard(
                      //         'Available Spaces',
                      //         context.watch<HomeProvider>().data['available']?.toString() ?? '0',
                      //         Icons.check_circle,
                      //         Colors.green,
                      //       ),
                      //     ),
                      //   ],
                      // ),
                      // const SizedBox(height: 24),

                      // Today's Statistics
                      // _buildSectionTitle('Today\'s Statistics'),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Prepaid Users',
                              context.watch<HomeProvider>().data['prepaid_user']?.toString() ?? '0',
                              Icons.people,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              'VIP Passes',
                              context.watch<HomeProvider>().data['vip_user']?.toString() ?? '0',
                              Icons.star,
                              Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              'Today\'s Passes',
                              context.watch<HomeProvider>().data['todays_pass']?.toString() ?? '0',
                              Icons.today,
                              Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Collection Card
                      // _buildSectionTitle('Today\'s Collection'),
                      // _buildCollectionCard(),
                      // const SizedBox(height: 20),

                      // Parking Status Chart
                      // _buildSectionTitle('Parking Status'),
                      _buildParkingChart(),
                      const SizedBox(height: 20),

                      // Quick Actions
                      _buildSectionTitle('Quick Actions'),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              'Entry',
                              Icons.login,
                              ConstColors.themeColor,
                              () async {
                                await RouteHelper.push(context, () => CheckInPage());
                                if (mounted) {
                                  context.read<HomeProvider>().loadData(context);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildActionCard(
                              'Exit',
                              Icons.logout,
                              Colors.red,
                              () async {
                                await RouteHelper.push(context, () => CheckOutPage());
                                if (mounted) {
                                  context.read<HomeProvider>().loadData(context);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              'Re-Print',
                              Icons.print,
                              Colors.orange,
                              () async {
                                await RouteHelper.push(context, () => Reprint());
                                if (mounted) {
                                  context.read<HomeProvider>().loadData(context);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildActionCard(
                              'Check Price',
                              Icons.currency_rupee,
                              Colors.green,
                              () async {
                                await RouteHelper.push(context, () => CheckPricePage());
                                if (mounted) {
                                  context.read<HomeProvider>().loadData(context);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              'Parking Rates',
                              Icons.money,
                              Colors.purple,
                              () async {
                                await RouteHelper.push(context, () => ParkingRatesPage());
                                if (mounted) {
                                  context.read<HomeProvider>().loadData(context);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildActionCard(
                              'Settings',
                              Icons.settings,
                              Colors.indigo,
                              () async {
                                await RouteHelper.push(context, () => const PrintSettingsPage());
                              },
                            ),
                          ),
                        ],
                      ),
                      if (kDebugMode) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionCard(
                                'Local DB',
                                Icons.storage,
                                Colors.teal,
                                () async {
                                  await RouteHelper.push(context, () => const LocalDbViewPage());
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(child: SizedBox.shrink()),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
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
          _buildHeaderButton(
            Icons.sync,
            () {
              _runManualSync();
            },
          ),
          const SizedBox(width: 12),
          _buildHeaderButton(
            Icons.logout,
            () {
              _handleLogout();
            },
          ),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF2E2C49),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF3F3C65),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionCard() {
    final Map data = context.watch<HomeProvider>().data;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, const Color(0xFFEFF7FF)],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: ConstColors.themeColor,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.currency_rupee,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹${data['total_col']?.toString() ?? '0'}',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E2C49),
                    ),
                  ),
                  Text(
                    'Today\'s Collection',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF3F3C65),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParkingChart() {
    final Map data = context.watch<HomeProvider>().data;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            HomePieChart(
              availableParking: data['available'] ?? 0,
              occupiedParking: data['occupied'] ?? 0,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Parking Status',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2E2C49),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStatusItem('Occupied', data['occupied']?.toString() ?? '0', const Color(0xFF0E67B7)),
                  const SizedBox(height: 8),
                  _buildStatusItem('Available', data['available']?.toString() ?? '0', const Color(0xFFFE595C)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: $value',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
