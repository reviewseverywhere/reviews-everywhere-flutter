import 'package:flutter/material.dart';
import 'package:cards/core/theme/app_theme.dart';
import 'package:cards/features/onboarding/data/onboarding_service.dart';

class OnboardingPage extends StatefulWidget {
  static const routeName = '/onboarding';
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _currentStep = 0;
  bool _saving = false;

  final _purchaserNameController = TextEditingController();
  final _slotsController = TextEditingController(text: '10');
  final _gbpUrlController = TextEditingController();

  List<TextEditingController> _wristbandControllers = [];
  List<TeamEditorData> _teams = [];
  Map<int, String?> _wristbandAssignments = {};

  @override
  void initState() {
    super.initState();
    _wristbandControllers = [
      TextEditingController(),
      TextEditingController(),
    ];
    _teams = [
      TeamEditorData(
        nameController: TextEditingController(text: 'My First Team'),
        memberControllers: [
          TextEditingController(),
          TextEditingController(),
        ],
      ),
    ];
  }

  @override
  void dispose() {
    _purchaserNameController.dispose();
    _slotsController.dispose();
    _gbpUrlController.dispose();
    for (var c in _wristbandControllers) {
      c.dispose();
    }
    for (var t in _teams) {
      t.dispose();
    }
    super.dispose();
  }

  void _next() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    }
  }

  void _back() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _finishSetup() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final wristbandNames = _wristbandControllers
          .map((c) => c.text.trim())
          .where((n) => n.isNotEmpty)
          .toList();

      final teams = _teams.map((t) => TeamData(
        name: t.nameController.text.trim(),
        members: t.memberControllers
            .map((c) => c.text.trim())
            .where((m) => m.isNotEmpty)
            .toList(),
      )).toList();

      final assignments = <String, String?>{};
      _wristbandAssignments.forEach((idx, memberId) {
        if (idx < wristbandNames.length) {
          assignments[wristbandNames[idx]] = memberId;
        }
      });

      final data = OnboardingData(
        purchaserName: _purchaserNameController.text.trim(),
        initialSlots: int.tryParse(_slotsController.text) ?? 10,
        wristbandNames: wristbandNames,
        teams: teams,
        wristbandAssignments: assignments,
        gbpUrl: _gbpUrlController.text.trim(),
      );

      await OnboardingService().completeOnboarding(data);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _getAllMembers() {
    final members = <String>[];
    for (var t in _teams) {
      for (var mc in t.memberControllers) {
        final name = mc.text.trim();
        if (name.isNotEmpty) {
          members.add(name);
        }
      }
    }
    return members;
  }

  int _unassignedCount() {
    final wristbands = _wristbandControllers
        .where((c) => c.text.trim().isNotEmpty)
        .toList();
    int unassigned = 0;
    for (int i = 0; i < wristbands.length; i++) {
      if (_wristbandAssignments[i] == null ||
          _wristbandAssignments[i]!.isEmpty) {
        unassigned++;
      }
    }
    return unassigned;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _buildCurrentStep(),
                ),
              ),
              _buildNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              StepPill(
                currentStep: _currentStep + 1,
                totalSteps: 4,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Image.asset(
              'assets/logo_1.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStep1() {
    return _OnboardingCard(
      title: 'Welcome & Initial Setup',
      description: "Welcome! Let's get your Reviews Everywhere dashboard set up. We'll start with some basic information.",
      children: [
        _PremiumInputField(
          label: 'Your Name (Purchaser)',
          hint: 'e.g., Jane Doe',
          controller: _purchaserNameController,
        ),
        const SizedBox(height: AppSpacing.lg),
        _PremiumInputField(
          label: 'Number of Initial Wristband Slots',
          hint: '10',
          controller: _slotsController,
          keyboardType: TextInputType.number,
          helperText: "This determines how many wristband inputs you'll start with. You can always add more later.",
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return _OnboardingCard(
      title: 'Define Your Wristbands',
      description: "Now, give your wristbands custom names. These will help you identify them easily later. Each wristband starts unassigned.",
      children: [
        ...List.generate(_wristbandControllers.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _wristbandControllers[i],
                      decoration: InputDecoration(
                        hintText: 'Wristband name (e.g., Lobby Band)',
                        hintStyle: AppTextStyles.caption,
                        filled: false,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 16),
                    ),
                  ),
                  if (_wristbandControllers.length > 1)
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentLight,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.orange, size: 18),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _wristbandControllers[i].dispose();
                            _wristbandControllers.removeAt(i);
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
          ),
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _wristbandControllers.add(TextEditingController());
              });
            },
            icon: const Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
            label: Text(
              'Add Another Wristband',
              style: AppTextStyles.button.copyWith(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return _OnboardingCard(
      title: 'Define Your Teams and Members',
      description: "Who will be using these wristbands? Organize your team members into teams. You need at least 2 members overall to start.",
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Suggestion: Consider one team for all members, or two smaller teams (1-2 members each).',
                  style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ...List.generate(_teams.length, (ti) => _buildTeamEditor(ti)),
      ],
    );
  }

  Widget _buildTeamEditor(int teamIndex) {
    final team = _teams[teamIndex];
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TEAM NAME', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: team.nameController,
              style: AppTextStyles.bodyBold.copyWith(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'My First Team',
                hintStyle: AppTextStyles.caption,
                filled: true,
                fillColor: AppColors.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('TEAM MEMBERS', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 10),
          ...List.generate(team.memberControllers.length, (mi) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person_outline, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: team.memberControllers[mi],
                        decoration: InputDecoration(
                          hintText: 'Member ${mi + 1} Name',
                          hintStyle: AppTextStyles.caption,
                          filled: false,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        style: AppTextStyles.bodyBold.copyWith(fontSize: 16),
                      ),
                    ),
                    if (team.memberControllers.length > 1)
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentLight,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.orange, size: 16),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setState(() {
                              team.memberControllers[mi].dispose();
                              team.memberControllers.removeAt(mi);
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              setState(() {
                team.memberControllers.add(TextEditingController());
              });
            },
            icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
            label: Text(
              'Add Member',
              style: AppTextStyles.button.copyWith(color: AppColors.primary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    final wristbands = _wristbandControllers
        .asMap()
        .entries
        .where((e) => e.value.text.trim().isNotEmpty)
        .toList();
    final members = _getAllMembers();
    final unassigned = _unassignedCount();

    return _OnboardingCard(
      title: 'Assign Wristbands & Set Profile URL',
      description: "Assign your wristbands to your team members and provide a Google Business Profile URL for all teams. This URL will be associated with all assigned wristbands.",
      children: [
        _PremiumInputField(
          label: 'Google Business Profile URL (for all teams)',
          hint: 'e.g., https://business.google.com/dashboard/l/your_business_id',
          controller: _gbpUrlController,
          helperText: 'This URL will be linked to all wristbands assigned to a team member.',
        ),
        const SizedBox(height: 28),
        Text('ASSIGN WRISTBANDS', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 14),
        if (wristbands.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.info_outline, color: AppColors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No wristbands defined. Go back to Step 2.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.orange),
                  ),
                ),
              ],
            ),
          )
        else
          ...wristbands.map((entry) {
            final idx = entry.key;
            final name = entry.value.text.trim();
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.watch, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Text(name, style: AppTextStyles.bodyBold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _wristbandAssignments[idx],
                          isExpanded: true,
                          hint: Text('Unassigned', style: AppTextStyles.caption),
                          style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text('Unassigned', style: AppTextStyles.caption),
                            ),
                            ...members.map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m, style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
                            )),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _wristbandAssignments[idx] = v;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        if (unassigned > 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: AppColors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You still have $unassigned wristband(s) unassigned.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.orange, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNavigation() {
    final isFirstStep = _currentStep == 0;
    final isLastStep = _currentStep == 3;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (!isFirstStep)
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: TextButton(
                    onPressed: _back,
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      'Back',
                      style: AppTextStyles.button.copyWith(color: AppColors.primary),
                    ),
                  ),
                ),
              ),
            if (!isFirstStep) const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.9),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: _saving
                      ? null
                      : (isLastStep ? _finishSetup : _next),
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isLastStep ? 'Finish Setup' : 'Next',
                          style: AppTextStyles.button.copyWith(color: Colors.white),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TeamEditorData {
  final TextEditingController nameController;
  final List<TextEditingController> memberControllers;

  TeamEditorData({
    required this.nameController,
    required this.memberControllers,
  });

  void dispose() {
    nameController.dispose();
    for (var c in memberControllers) {
      c.dispose();
    }
  }
}

class _OnboardingCard extends StatelessWidget {
  final String title;
  final String description;
  final List<Widget> children;

  const _OnboardingCard({
    required this.title,
    required this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.headline),
            const SizedBox(height: 12),
            Text(description, style: AppTextStyles.body),
            const SizedBox(height: 28),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PremiumInputField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? helperText;
  final bool readOnly;

  const _PremiumInputField({
    required this.label,
    this.hint,
    required this.controller,
    this.keyboardType,
    this.helperText,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTextStyles.sectionLabel),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            style: AppTextStyles.bodyBold.copyWith(fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTextStyles.caption,
              filled: true,
              fillColor: AppColors.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              suffixIcon: readOnly
                  ? const Icon(Icons.lock_outline, size: 18, color: AppColors.textMuted)
                  : null,
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 10),
          Text(helperText!, style: AppTextStyles.caption),
        ],
      ],
    );
  }
}
