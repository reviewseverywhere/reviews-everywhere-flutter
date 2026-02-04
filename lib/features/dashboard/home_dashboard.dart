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
                borderRadius: BorderRadius.circular(AppRadius.lg),
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
          borderRadius: BorderRadius.circular(AppRadius.lg),
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
            child: const Text('OK'),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
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
          borderRadius: BorderRadius.circular(AppRadius.lg),
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

    return SafeArea(
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
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Image.asset('assets/logo_1.png', width: 48, height: 48),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reviews Everywhere',
                  style: AppTextStyles.h3,
                ),
                Text(
                  'Dashboard',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          if (kDebugMode && !_nfcAvailable)
            TextButton(
              onPressed: () => setState(() => _simulatorMode = !_simulatorMode),
              child: Text(
                _simulatorMode ? 'SIM ON' : 'SIM OFF',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _simulatorMode ? AppColors.green : AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAccountSummary() {
    if (_loadingAccount) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final data = _accountData;
    if (data == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.orange.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.orange),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'No account record found. This usually means Shopify has not processed your order yet.',
                  style: TextStyle(fontSize: 13, color: AppColors.orange),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final planStatus = (data['planStatus'] ?? '-').toString();
    final isActive = planStatus.toLowerCase() == 'active';
    final slotsAvailable = _asInt(data['slotsAvailable']);
    final slotsUsed = _asInt(data['slotsUsed']);
    final slotsNet = _asInt(data['slotsNet']);
    final slotsPurchased = _asInt(data['slotsPurchasedTotal']);
    final slotsRefunded = _asInt(data['slotsRefundedTotal']);
    final updatedAt = data['updatedAt'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: (isActive ? AppColors.green : AppColors.orange).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: (isActive ? AppColors.green : AppColors.orange).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive ? Icons.check_circle : Icons.warning_amber,
                      size: 16,
                      color: isActive ? AppColors.green : AppColors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Plan: $planStatus',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isActive ? AppColors.green : AppColors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Updated: ${_fmtTs(updatedAt)}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: _StatCard(title: 'Available', value: '$slotsAvailable', color: AppColors.green)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _StatCard(title: 'Used', value: '$slotsUsed', color: AppColors.blue)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _StatCard(title: 'Net', value: '$slotsNet', color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _StatCard(title: 'Purchased', value: '$slotsPurchased', color: AppColors.textSecondary)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _StatCard(title: 'Refunded', value: '$slotsRefunded', color: AppColors.orange)),
              const SizedBox(width: AppSpacing.md),
              const Expanded(child: SizedBox()),
            ],
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
          color: AppColors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.red.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.nfc, color: AppColors.red, size: 24),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'NFC is not available on this device. Enable NFC in Settings (if supported) or use Simulator Mode in debug builds.',
                style: TextStyle(fontSize: 13, color: AppColors.red, fontWeight: FontWeight.w500),
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
          Text('Quick Actions', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.md),
          _ActionCard(
            icon: Icons.edit_note,
            title: 'Write URL',
            description: 'Program a wristband with a custom URL',
            color: AppColors.blue,
            onTap: canUseNfc ? _showEnterUrl : () => _snack('NFC not available'),
            enabled: canUseNfc,
          ),
          const SizedBox(height: AppSpacing.md),
          _ActionCard(
            icon: Icons.delete_sweep,
            title: 'Clear URL',
            description: 'Remove the URL from a wristband',
            color: AppColors.orange,
            onTap: canUseNfc ? _showConfirmClear : () => _snack('NFC not available'),
            enabled: canUseNfc,
          ),
          const SizedBox(height: AppSpacing.md),
          _ActionCard(
            icon: Icons.visibility,
            title: 'View Slots',
            description: 'See your account and slot details',
            color: AppColors.primary,
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
          borderRadius: BorderRadius.circular(AppRadius.lg),
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
                      color: (isActive ? AppColors.green : AppColors.orange).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isActive ? AppColors.green : AppColors.orange),
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
            child: const Text('Close'),
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: enabled ? AppColors.textSecondary : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: enabled ? AppColors.textMuted : AppColors.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
