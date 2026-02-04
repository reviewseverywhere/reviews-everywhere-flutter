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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: _buildCurrentStep(),
              ),
            ),
            _buildNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Image.asset('assets/logo_1.png', width: 40, height: 40),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text(
              'Reviews Everywhere',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              'Step ${_currentStep + 1} of 4',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
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
    return _StepCard(
      title: 'Welcome & Initial Setup',
      description: "Welcome! Let's get your Reviews Everywhere dashboard set up. We'll start with some basic information.",
      children: [
        _InputField(
          label: 'Your Name (Purchaser)',
          hint: 'e.g., Jane Doe',
          controller: _purchaserNameController,
        ),
        const SizedBox(height: AppSpacing.lg),
        _InputField(
          label: 'Number of Initial Wristband Slots',
          hint: '10',
          controller: _slotsController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          "This determines how many wristband inputs you'll start with. You can always add more later.",
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return _StepCard(
      title: 'Define Your Wristbands',
      description: "Now, give your wristbands custom names. These will help you identify them easily later. Each wristband starts unassigned.",
      children: [
        ...List.generate(_wristbandControllers.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _wristbandControllers[i],
                    decoration: AppWidgets.inputDecoration(
                      label: '',
                      hint: 'Wristband ${i + 1} Custom Name (e.g., Lobby Band)',
                    ),
                  ),
                ),
                if (_wristbandControllers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () {
                      setState(() {
                        _wristbandControllers[i].dispose();
                        _wristbandControllers.removeAt(i);
                      });
                    },
                  ),
              ],
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
          icon: const Icon(Icons.add),
          label: const Text('Add Another Wristband'),
          style: AppWidgets.outlineButton(),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return _StepCard(
      title: 'Define Your Teams and Members',
      description: "Who will be using these wristbands? Organize your team members into teams. You need at least 2 members overall to start.",
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.accent.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppColors.accent, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Suggestion: Consider one team for all members, or two smaller teams (1-2 members each).',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
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
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Team Name', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: team.nameController,
            decoration: AppWidgets.inputDecoration(
              label: '',
              hint: 'My First Team',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Team Members:', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.sm),
          ...List.generate(team.memberControllers.length, (mi) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: team.memberControllers[mi],
                      decoration: AppWidgets.inputDecoration(
                        label: '',
                        hint: 'Member ${mi + 1} Name',
                      ),
                    ),
                  ),
                  if (team.memberControllers.length > 1)
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () {
                        setState(() {
                          team.memberControllers[mi].dispose();
                          team.memberControllers.removeAt(mi);
                        });
                      },
                    ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () {
              setState(() {
                team.memberControllers.add(TextEditingController());
              });
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Member'),
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

    return _StepCard(
      title: 'Assign Wristbands & Set Profile URL',
      description: "Assign your wristbands to your team members and provide a Google Business Profile URL for all teams. This URL will be associated with all assigned wristbands.",
      children: [
        _InputField(
          label: 'Google Business Profile URL (for all teams)',
          hint: 'e.g., https://business.google.com/dashboard/l/your_business_id',
          controller: _gbpUrlController,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'This URL will be linked to all wristbands assigned to a team member.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Assign Wristbands:', style: AppTextStyles.bodyBold),
        const SizedBox(height: AppSpacing.md),
        if (wristbands.isEmpty)
          Text(
            'No wristbands defined. Go back to Step 2.',
            style: AppTextStyles.caption,
          )
        else
          ...wristbands.map((entry) {
            final idx = entry.key;
            final name = entry.value.text.trim();
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(name, style: AppTextStyles.body),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _wristbandAssignments[idx],
                      decoration: AppWidgets.inputDecoration(label: ''),
                      hint: const Text('-- Unassigned --'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('-- Unassigned --'),
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
                ],
              ),
            );
          }),
        if (unassigned > 0) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: AppColors.orange, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'You still have $unassigned wristband(s) unassigned.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.orange,
                      fontWeight: FontWeight.w500,
                    ),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _back,
              child: const Text(
                'Back',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const Spacer(),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: AppWidgets.primaryButton(),
              onPressed: _saving
                  ? null
                  : (_currentStep == 3 ? _finishSetup : _next),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _currentStep == 3 ? 'Finish Setup' : 'Next',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
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

class _StepCard extends StatelessWidget {
  final String title;
  final String description;
  final List<Widget> children;

  const _StepCard({
    required this.title,
    required this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h1),
          const SizedBox(height: AppSpacing.sm),
          Text(description, style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.xl),
          ...children,
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  const _InputField({
    required this.label,
    this.hint,
    required this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: AppWidgets.inputDecoration(
            label: '',
            hint: hint,
          ),
        ),
      ],
    );
  }
}
