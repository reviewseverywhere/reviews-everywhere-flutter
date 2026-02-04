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
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 80),
          Image.asset('assets/logo_1.png', width: 64, height: 64),
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: StepPill(
                currentStep: _currentStep + 1,
                totalSteps: 4,
              ),
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
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _wristbandControllers[i],
                      decoration: InputDecoration(
                        hintText: 'Wristband ${i + 1} (e.g., Lobby Band)',
                        hintStyle: AppTextStyles.caption,
                        filled: false,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  if (_wristbandControllers.length > 1)
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.orange, width: 1.5),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: AppColors.orange, size: 18),
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
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _wristbandControllers.add(TextEditingController());
            });
          },
          icon: const Icon(Icons.add, color: AppColors.primary),
          label: const Text('Add Another Wristband'),
          style: AppWidgets.outlineButton(),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return _OnboardingCard(
      title: 'Define Your Teams and Members',
      description: "Who will be using these wristbands? Organize your team members into teams. You need at least 2 members overall to start.",
      children: [
        const InfoBanner(
          message: 'Suggestion: Consider one team for all members, or two smaller teams (1-2 members each).',
          icon: Icons.lightbulb_outline,
        ),
        const SizedBox(height: AppSpacing.lg),
        ...List.generate(_teams.length, (ti) => _buildTeamEditor(ti)),
      ],
    );
  }

  Widget _buildTeamEditor(int teamIndex) {
    final team = _teams[teamIndex];
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TEAM NAME', style: AppTextStyles.sectionLabel),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: team.nameController,
            decoration: AppWidgets.inputDecoration(
              label: '',
              hint: 'My First Team',
            ),
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('TEAM MEMBERS', style: AppTextStyles.sectionLabel),
          const SizedBox(height: AppSpacing.sm),
          ...List.generate(team.memberControllers.length, (mi) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: team.memberControllers[mi],
                        decoration: InputDecoration(
                          hintText: 'Member ${mi + 1} Name',
                          hintStyle: AppTextStyles.caption,
                          filled: false,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    if (team.memberControllers.length > 1)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.orange, width: 1.5),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: AppColors.orange, size: 18),
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
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () {
              setState(() {
                team.memberControllers.add(TextEditingController());
              });
            },
            icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
            label: const Text('Add Member', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
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
        const SizedBox(height: AppSpacing.xl),
        Text('ASSIGN WRISTBANDS', style: AppTextStyles.sectionLabel),
        const SizedBox(height: AppSpacing.md),
        if (wristbands.isEmpty)
          const InfoBanner(
            message: 'No wristbands defined. Go back to Step 2.',
            icon: Icons.info_outline,
            isWarning: true,
          )
        else
          ...wristbands.map((entry) {
            final idx = entry.key;
            final name = entry.value.text.trim();
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(name, style: AppTextStyles.bodyBold),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _wristbandAssignments[idx],
                          isExpanded: true,
                          hint: const Text('Unassigned', style: TextStyle(color: AppColors.textMuted)),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Unassigned'),
                            ),
                            ...members.map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m),
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
          const SizedBox(height: AppSpacing.md),
          InfoBanner(
            message: 'You still have $unassigned wristband(s) unassigned.',
            icon: Icons.warning_amber,
            isWarning: true,
          ),
        ],
      ],
    );
  }

  Widget _buildNavigation() {
    final isFirstStep = _currentStep == 0;
    final isLastStep = _currentStep == 3;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (!isFirstStep)
              Expanded(
                child: OutlinedButton(
                  onPressed: _back,
                  style: AppWidgets.secondaryButton(),
                  child: const Text('Back'),
                ),
              ),
            if (!isFirstStep) const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: isFirstStep ? 1 : 1,
              child: ElevatedButton(
                style: AppWidgets.primaryButton(),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 16,
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
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.headline),
            const SizedBox(height: AppSpacing.sm),
            Text(description, style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppSpacing.xl),
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
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          style: const TextStyle(fontSize: 16),
          decoration: AppWidgets.inputDecoration(
            label: '',
            hint: hint,
            readOnly: readOnly,
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(helperText!, style: AppTextStyles.caption),
        ],
      ],
    );
  }
}
