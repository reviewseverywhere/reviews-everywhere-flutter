import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cards/core/theme/app_theme.dart';
import 'package:cards/core/widgets/premium_widgets.dart';
import 'package:cards/features/dashboard/tour_data.dart';
import 'package:cards/features/onboarding/presentation/pages/onboarding_page.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static bool _tourCompletedThisSession = false;

  Map<String, dynamic>? _accountData;
  bool _loadingAccount = true;

  bool _showTour = false;
  int _tourStep = 0;

  @override
  void initState() {
    super.initState();
    _loadAccountData();
    if (!_tourCompletedThisSession) {
      _showTour = true;
      _tourStep = 0;
    }
  }

  void _completeTour() {
    _tourCompletedThisSession = true;
    if (mounted) {
      setState(() => _showTour = false);
    }
  }

  Future<void> _loadAccountData() async {
    final email = FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      if (mounted) setState(() => _loadingAccount = false);
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

  @override
  Widget build(BuildContext context) {
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
}
