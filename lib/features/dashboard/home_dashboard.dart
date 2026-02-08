import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cards/core/theme/app_theme.dart';
import 'package:cards/core/widgets/premium_widgets.dart';
import 'package:cards/features/dashboard/tour_data.dart';
import 'package:cards/features/nfc_tag/presentation/viewmodels/home_view_model.dart';
import 'package:cards/features/nfc_tag/presentation/pages/enter_url_page.dart';
import 'package:cards/features/nfc_tag/presentation/widgets/validation_dialog.dart';
import 'package:cards/features/nfc_tag/presentation/widgets/confirm_clear_dialog.dart';
import 'package:cards/features/onboarding/presentation/pages/onboarding_page.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final _urlController = TextEditingController();
  late final HomeViewModel _vm;
  bool _nfcAvailable = false;
  bool _simulatorMode = false;
  bool _scanningDialogShowing = false;

  Map<String, dynamic>? _accountData;
  bool _loadingAccount = true;

  bool _showTour = false;
  int _tourStep = 0;

  @override
  void initState() {
    super.initState();
    NfcManager.instance.isAvailable().then((v) {
      if (mounted) setState(() => _nfcAvailable = v);
    });

    _vm = context.read<HomeViewModel>();
    _vm.addListener(_onVmStateChanged);
    _loadAccountData();
    _checkTourStatus();
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmStateChanged);
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _checkTourStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('dashboardTourCompleted') ?? false;
    if (!completed && mounted) {
      setState(() {
        _showTour = true;
        _tourStep = 0;
      });
    }
  }

  Future<void> _completeTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dashboardTourCompleted', true);
    if (mounted) {
      setState(() => _showTour = false);
    }
  }

  Future<void> _loadAccountData() async {
    final email = FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      setState(() => _loadingAccount = false);
      return;
    }

    try {
      final q = await FirebaseFirestore.instance
          .collection('accounts')
          .where('shopifyEmail', isEqualTo: email)
          .limit(1)
          .get();

      if (mounted) {
        setState(() {
          _accountData = q.docs.isNotEmpty ? q.docs.first.data() : null;
          _loadingAccount = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingAccount = false);
    }
  }

  void _onVmStateChanged() {
    switch (_vm.state) {
      case ViewState.busy:
        if (!_scanningDialogShowing) {
          _scanningDialogShowing = true;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              title: const Text('Scanning NFC Tag'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset(
                    'assets/scanner.json',
                    width: 150,
                    height: 150,
                    repeat: true,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  const Text('Hold your device close to the NFC card'),
                ],
              ),
            ),
          );
        }
        break;

      case ViewState.success:
      case ViewState.error:
        if (_scanningDialogShowing) {
          Navigator.of(context, rootNavigator: true).pop();
          _scanningDialogShowing = false;
        }

        if (_vm.state == ViewState.success) {
          if (_vm.lastAction == NfcAction.write) {
            _showResultDialog('Success', 'Card written successfully!', true);
          } else if (_vm.lastAction == NfcAction.clear) {
            _showResultDialog('Success', 'Card cleared successfully!', true);
          }
        } else {
          if (_vm.errorMessage == 'EMPTY_TAG') {
            _showResultDialog('Info', 'Card has nothing to clear — it is already empty.', false);
          } else {
            _showResultDialog('Error', _vm.errorMessage ?? 'Unknown error', false);
          }
        }
        break;

      case ViewState.idle:
        break;
    }
  }

  Future<void> _showResultDialog(String title, String message, bool success) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.info,
              color: success ? AppColors.green : AppColors.orange,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.textPrimary,
      ),
    );
  }

  Future<void> _launchAddWristband() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const OnboardingPage(addWristbandMode: true),
      ),
    );

    if (result == true && mounted) {
      _loadAccountData();
      _snack('Wristband added successfully!');
    }
  }

  Future<void> _showEnterUrl() async {
    _urlController.clear();

    final tappedSet = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EnterUrlPage(controller: _urlController)),
    );
    if (tappedSet != true) return;

    final url = _urlController.text.trim();
    if (url.isEmpty) return _snack('URL cannot be empty');

    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ValidationDialog(
        url: url,
        validator: _vm.checkUrl,
      ),
    );

    if (proceed == true) {
      if (_simulatorMode) {
        await _showSimScanDialog(
          title: 'Simulating NFC Write',
          note: 'Simulator Mode: writing URL to Firestore',
        );
        await _writeSimTagUrl(url);
        await _showResultDialog('Success', '(Simulated) Card written successfully!', true);
      } else {
        _vm.onWrite(url);
      }
    }
  }

  Future<void> _showConfirmClear() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ConfirmClearDialog(),
    );

    if (confirm == true) {
      if (_simulatorMode) {
        await _showSimScanDialog(
          title: 'Simulating NFC Clear',
          note: 'Simulator Mode: clearing stored URL in Firestore',
        );
        await _clearSimTagUrl();
        await _showResultDialog('Success', '(Simulated) Card cleared successfully!', true);
      } else {
        _vm.onClear();
      }
    }
  }

  Future<void> _writeSimTagUrl(String url) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    await FirebaseFirestore.instance.collection('sim_nfc_tags').doc(uid).set(
      <String, dynamic>{
        'url': url,
        'mode': 'simulated',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _clearSimTagUrl() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    await FirebaseFirestore.instance.collection('sim_nfc_tags').doc(uid).set(
      <String, dynamic>{
        'url': '',
        'mode': 'simulated',
        'updatedAt': FieldValue.serverTimestamp(),
        'clearedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _showSimScanDialog({required String title, required String note}) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/scanner.json',
              width: 150,
              height: 150,
              repeat: true,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 12),
            Text(note),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 900));

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  String _greeting() {
    final data = _accountData;
    String name = 'there';
    if (data != null) {
      final display = data['displayName'] as String?;
      final first = data['firstName'] as String?;
      if (display != null && display.trim().isNotEmpty) {
        name = display.trim().split(' ').first;
      } else if (first != null && first.trim().isNotEmpty) {
        name = first.trim();
      }
    }
    final user = FirebaseAuth.instance.currentUser;
    if (name == 'there' && user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      name = user.displayName!.trim().split(' ').first;
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final canUseNfc = _nfcAvailable || _simulatorMode;

    return Stack(
      children: [
        GradientBackground(
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadAccountData,
              color: AppColors.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverToBoxAdapter(child: _buildSlotSummaryCard()),
                  SliverToBoxAdapter(child: _buildQuickActions(canUseNfc)),
                  SliverToBoxAdapter(child: _buildRecentActivity()),
                  SliverToBoxAdapter(child: _buildSupportCard()),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ),
        ),
        if (_showTour) _buildTourOverlay(),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kDebugMode && !_nfcAvailable) ...[
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => setState(() => _simulatorMode = !_simulatorMode),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _simulatorMode ? AppColors.greenLight : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: _simulatorMode ? AppColors.green : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _simulatorMode ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 14,
                        color: _simulatorMode ? AppColors.green : AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Sim',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _simulatorMode ? AppColors.green : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            'Hi, ${_greeting()}',
            style: GoogleFonts.raleway(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.2,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Here\'s your dashboard overview',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotSummaryCard() {
    if (_loadingAccount) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final data = _accountData;
    if (data == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: PremiumCard(
          child: Column(
            children: [
              const Icon(Icons.info_outline, color: AppColors.orange, size: 32),
              const SizedBox(height: 12),
              Text(
                'No account record found',
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: 4),
              Text(
                'This usually means Shopify has not processed your order yet.',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final slotsAvailable = _asInt(data['slotsAvailable']);
    final slotsPurchased = _asInt(data['slotsPurchasedTotal']);
    final slotsUsed = _asInt(data['slotsUsed']);
    final slotsRefunded = _asInt(data['slotsRefundedTotal']);
    final hasRefunds = slotsRefunded > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WRISTBAND SLOTS',
              style: AppTextStyles.sectionLabel,
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Text(
                    '$slotsAvailable',
                    style: GoogleFonts.raleway(
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                      color: slotsAvailable > 0 ? AppColors.primary : AppColors.orange,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Available',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _slotMetric('Purchased', '$slotsPurchased', AppColors.primary),
                  Container(width: 1, height: 30, color: AppColors.border),
                  _slotMetric('Used', '$slotsUsed', AppColors.textPrimary),
                  if (hasRefunds) ...[
                    Container(width: 1, height: 30, color: AppColors.border),
                    _slotMetric('Refunded', '$slotsRefunded', AppColors.orange),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (slotsAvailable > 0)
              PrimaryButton(
                label: 'Add new wristband',
                icon: Icons.add_circle_outline,
                onPressed: _launchAddWristband,
              )
            else
              PillBadge(
                text: 'No slots available, buy more',
                backgroundColor: AppColors.accentLight,
                textColor: AppColors.orange,
                icon: Icons.info_outline,
              ),
          ],
        ),
      ),
    );
  }

  Widget _slotMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.raleway(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(bool canUseNfc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('QUICK ACTIONS', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.edit_note,
                  label: 'Write URL',
                  color: AppColors.primary,
                  onTap: canUseNfc ? _showEnterUrl : () => _snack('NFC not available'),
                  enabled: canUseNfc,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.delete_sweep,
                  label: 'Clear URL',
                  color: AppColors.orange,
                  onTap: canUseNfc ? _showConfirmClear : () => _snack('NFC not available'),
                  enabled: canUseNfc,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.visibility,
                  label: 'View Slots',
                  color: AppColors.textPrimary,
                  onTap: () => _loadAccountData().then((_) {
                    if (_accountData != null) {
                      _showSlotsDialog();
                    }
                  }),
                  enabled: true,
                ),
              ),
            ],
          ),
          if (!_nfcAvailable && !_simulatorMode) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  const Icon(Icons.nfc, color: AppColors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'NFC is not available. Enable it in Settings or use Simulator Mode.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.history, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Text('Recent activity', style: AppTextStyles.h3),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 40,
                    color: AppColors.textMuted.withOpacity(0.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No recent activity yet',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your wristband activity will show up here',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted.withOpacity(0.7),
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

  Widget _buildSupportCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: PremiumCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.headset_mic_outlined, size: 22, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need help?',
                    style: GoogleFonts.raleway(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'We\'re here for you',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () {
                _snack('Support contact coming soon');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                textStyle: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Contact support'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTourOverlay() {
    final step = dashboardTourSteps[_tourStep];
    return GestureDetector(
      onTap: () {},
      child: Container(
        color: Colors.black.withOpacity(0.6),
        child: Center(
          child: PremiumTourModal(
            title: step.title,
            body: step.body,
            currentStep: _tourStep + 1,
            totalSteps: dashboardTourSteps.length,
            onNext: () {
              if (_tourStep < dashboardTourSteps.length - 1) {
                setState(() => _tourStep++);
              } else {
                _completeTour();
              }
            },
            onPrev: _tourStep > 0 ? () => setState(() => _tourStep--) : null,
            onClose: _completeTour,
          ),
        ),
      ),
    );
  }

  Future<void> _showSlotsDialog() async {
    final data = _accountData;
    if (data == null) return;

    final planStatus = (data['planStatus'] ?? '-').toString();
    final isActive = planStatus.toLowerCase() == 'active';
    final slotsAvailable = _asInt(data['slotsAvailable']);
    final slotsUsed = _asInt(data['slotsUsed']);
    final slotsNet = _asInt(data['slotsNet']);
    final slotsPurchased = _asInt(data['slotsPurchasedTotal']);
    final slotsRefunded = _asInt(data['slotsRefundedTotal']);
    final updatedAt = data['updatedAt'];
    final entitlementUpdatedAt = data['entitlementUpdatedAt'];

    String fmtTs(dynamic ts) {
      if (ts is Timestamp) {
        final d = ts.toDate();
        return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
      }
      return '-';
    }

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: const Text('Account Overview'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Plan Status: ', style: TextStyle(fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isActive ? AppColors.greenLight : AppColors.accentLight),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      planStatus,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isActive ? AppColors.green : AppColors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const Text('Wristband Slots', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _metricRow('Available slots', '$slotsAvailable', valueColor: slotsAvailable > 0 ? AppColors.green : AppColors.orange),
              _metricRow('Used slots (activated)', '$slotsUsed'),
              _metricRow('Net slots', '$slotsNet'),
              const SizedBox(height: 10),
              const Divider(),
              const Text('Purchase Totals (from Shopify)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _metricRow('Purchased total', '$slotsPurchased'),
              _metricRow('Refunded total', '$slotsRefunded'),
              const SizedBox(height: 12),
              const Divider(),
              Text('Last account update: ${fmtTs(updatedAt)}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              Text('Last entitlement update: ${fmtTs(entitlementUpdatedAt)}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: color),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
