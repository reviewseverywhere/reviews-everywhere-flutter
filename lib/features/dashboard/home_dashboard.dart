import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:provider/provider.dart';
import 'package:cards/core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    NfcManager.instance.isAvailable().then((v) {
      if (mounted) setState(() => _nfcAvailable = v);
    });

    _vm = context.read<HomeViewModel>();
    _vm.addListener(_onVmStateChanged);
    _loadAccountData();
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmStateChanged);
    _urlController.dispose();
    super.dispose();
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

  String _fmtTs(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final canUseNfc = _nfcAvailable || _simulatorMode;

    return GradientBackground(
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildAccountSummary()),
            if (!_nfcAvailable && !_simulatorMode)
              SliverToBoxAdapter(child: _buildNfcBanner()),
            SliverToBoxAdapter(child: _buildActionCards(canUseNfc)),
            SliverToBoxAdapter(child: const SizedBox(height: AppSpacing.xl)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo_1.png', width: 56, height: 56),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Welcome back!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          if (kDebugMode && !_nfcAvailable) ...[
            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: () => setState(() => _simulatorMode = !_simulatorMode),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
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
                      size: 16,
                      color: _simulatorMode ? AppColors.green : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Simulator Mode',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _simulatorMode ? AppColors.green : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountSummary() {
    if (_loadingAccount) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final data = _accountData;
    if (data == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: const InfoBanner(
          message: 'No account record found. This usually means Shopify has not processed your order yet.',
          icon: Icons.info_outline,
          isWarning: true,
        ),
      );
    }

    final planStatus = (data['planStatus'] ?? '-').toString();
    final isActive = planStatus.toLowerCase() == 'active';
    final slotsAvailable = _asInt(data['slotsAvailable']);
    final slotsPurchased = _asInt(data['slotsPurchasedTotal']);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: (isActive ? AppColors.greenLight : AppColors.accentLight),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? Icons.check_circle : Icons.warning_amber,
                  size: 18,
                  color: isActive ? AppColors.green : AppColors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Plan: $planStatus',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isActive ? AppColors.green : AppColors.orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Available',
                  value: '$slotsAvailable',
                  icon: Icons.confirmation_number_outlined,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatCard(
                  title: 'Purchased',
                  value: '$slotsPurchased',
                  icon: Icons.shopping_bag_outlined,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (slotsAvailable > 0)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _launchAddWristband,
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text('Add new wristband'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'No slots available, buy more',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.orange,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNfcBanner() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.nfc, color: AppColors.orange, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Text(
                'NFC is not available on this device. Enable NFC in Settings or use Simulator Mode.',
                style: TextStyle(fontSize: 13, color: AppColors.orange, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCards(bool canUseNfc) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('QUICK ACTIONS', style: AppTextStyles.sectionLabel),
          const SizedBox(height: AppSpacing.md),
          ActionTile(
            icon: Icons.edit_note,
            title: 'Write URL',
            description: 'Program a wristband with a custom URL',
            color: AppColors.primary,
            onTap: canUseNfc ? _showEnterUrl : () => _snack('NFC not available'),
            enabled: canUseNfc,
            isPrimary: true,
          ),
          const SizedBox(height: AppSpacing.md),
          ActionTile(
            icon: Icons.delete_sweep,
            title: 'Clear URL',
            description: 'Remove the URL from a wristband',
            color: AppColors.orange,
            onTap: canUseNfc ? _showConfirmClear : () => _snack('NFC not available'),
            enabled: canUseNfc,
            isDestructive: true,
          ),
          const SizedBox(height: AppSpacing.md),
          ActionTile(
            icon: Icons.visibility,
            title: 'View Slots',
            description: 'See your account and slot details',
            color: AppColors.textPrimary,
            onTap: () => _loadAccountData().then((_) {
              if (_accountData != null) {
                _showSlotsDialog();
              }
            }),
            enabled: true,
          ),
        ],
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
              Text('Entitlements updated: ${_fmtTs(entitlementUpdatedAt)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              Text('Last updated: ${_fmtTs(updatedAt)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
