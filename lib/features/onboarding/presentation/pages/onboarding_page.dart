import 'package:flutter/material.dart';
import 'package:cards/core/theme/app_theme.dart';
import 'package:cards/features/onboarding/data/onboarding_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OnboardingPage extends StatefulWidget {
  static const routeName = '/onboarding';
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _currentStep = 0;
  bool _saving = false;
  bool _loadingAccountData = true;
  
  // ========== TEMPORARY DEBUG STATE (REMOVE AFTER VERIFICATION) ==========
  String? _debugAuthUid;
  String? _debugAuthEmail;
  String? _debugFirestorePath;
  bool? _debugDocExists;
  List<String>? _debugDocKeys;
  Map<String, dynamic>? _debugRawData;
  String? _debugPurchaserNameValue;
  String? _debugSlotCountValue;
  String? _debugErrorMessage;
  // ========== END DEBUG STATE ==========
  
  // Validation state
  String? _step1Error;
  String? _step2Error;
  String? _step3Error;
  String? _step4Error;
  int _maxWristbands = 10; // Set from Step 1

  final _purchaserNameController = TextEditingController();
  final _slotsController = TextEditingController(text: '10');
  final _gbpUrlController = TextEditingController();

  List<TextEditingController> _wristbandControllers = [];
  List<TeamEditorData> _teams = [];
  Map<int, String?> _wristbandAssignments = {};

  @override
  void initState() {
    super.initState();
    // Initialize with empty wristband list - will be populated from Step 1
    _wristbandControllers = [];
    _teams = [
      TeamEditorData(
        nameController: TextEditingController(text: ''),
        memberControllers: [
          TextEditingController(),
          TextEditingController(),
        ],
      ),
    ];
    
    // Listen for changes to trigger validation
    _purchaserNameController.addListener(_onStep1Changed);
    _slotsController.addListener(_onStep1Changed);
    _gbpUrlController.addListener(_onStep4Changed);
    
    // Load existing account data to prefill Step 1
    _loadAccountData();
  }
  
  /// Fetches the account document from Firestore using the same logic as View Slots
  Future<DocumentSnapshot<Map<String, dynamic>>?> _getAccountDoc() async {
    final email = FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return null;

    final q = await FirebaseFirestore.instance
        .collection('accounts')
        .where('shopifyEmail', isEqualTo: email)
        .limit(1)
        .get();

    if (q.docs.isEmpty) return null;
    return q.docs.first;
  }
  
  /// Loads existing account data and prefills Step 1 fields
  Future<void> _loadAccountData() async {
    try {
      // ========== DEBUG: Capture auth info ==========
      final currentUser = FirebaseAuth.instance.currentUser;
      _debugAuthUid = currentUser?.uid ?? 'NULL';
      _debugAuthEmail = currentUser?.email ?? 'NULL';
      
      final email = currentUser?.email?.trim().toLowerCase();
      _debugFirestorePath = email != null 
          ? "accounts WHERE shopifyEmail == '$email' LIMIT 1"
          : "NO EMAIL - CANNOT QUERY";
      
      if (email == null || email.isEmpty) {
        _debugDocExists = false;
        _debugDocKeys = [];
        _debugErrorMessage = 'No email from FirebaseAuth.currentUser';
        if (mounted) setState(() => _loadingAccountData = false);
        return;
      }
      
      // Fetch document using same logic as View Slots
      final q = await FirebaseFirestore.instance
          .collection('accounts')
          .where('shopifyEmail', isEqualTo: email)
          .limit(1)
          .get();
      
      if (q.docs.isEmpty) {
        _debugDocExists = false;
        _debugDocKeys = [];
        _debugErrorMessage = 'Query returned 0 documents';
        if (mounted) setState(() => _loadingAccountData = false);
        return;
      }
      
      final doc = q.docs.first;
      _debugDocExists = doc.exists;
      _debugFirestorePath = 'accounts/${doc.id}';
      
      final data = doc.data();
      _debugDocKeys = data.keys.toList()..sort();
      _debugRawData = data;
      
      // Extract purchaser name (try displayName first, then firstName + lastName)
      String purchaserName = '';
      if (data['displayName'] != null && data['displayName'].toString().trim().isNotEmpty) {
        purchaserName = data['displayName'].toString().trim();
      } else {
        final firstName = (data['firstName'] ?? '').toString().trim();
        final lastName = (data['lastName'] ?? '').toString().trim();
        purchaserName = '$firstName $lastName'.trim();
      }
      _debugPurchaserNameValue = purchaserName.isEmpty ? '(empty string)' : purchaserName;
      
      // Extract slots (use slotsNet as the purchased entitlement count)
      int slots = 10; // default fallback
      String slotSource = 'default (10)';
      if (data['slotsNet'] != null) {
        final parsed = int.tryParse(data['slotsNet'].toString());
        if (parsed != null && parsed > 0 && parsed <= 50) {
          slots = parsed;
          slotSource = 'slotsNet: ${data['slotsNet']}';
        }
      } else if (data['slotsAvailable'] != null) {
        final parsed = int.tryParse(data['slotsAvailable'].toString());
        if (parsed != null && parsed > 0 && parsed <= 50) {
          slots = parsed;
          slotSource = 'slotsAvailable: ${data['slotsAvailable']}';
        }
      } else if (data['slotsPurchasedTotal'] != null) {
        final parsed = int.tryParse(data['slotsPurchasedTotal'].toString());
        if (parsed != null && parsed > 0 && parsed <= 50) {
          slots = parsed;
          slotSource = 'slotsPurchasedTotal: ${data['slotsPurchasedTotal']}';
        }
      }
      _debugSlotCountValue = '$slots (from $slotSource)';
      
      // Prefill controllers
      if (purchaserName.isNotEmpty) {
        _purchaserNameController.text = purchaserName;
      }
      _slotsController.text = slots.toString();
      _maxWristbands = slots;
      
      debugPrint('[Onboarding] Prefilled: name="$purchaserName", slots=$slots');
    } catch (e, st) {
      debugPrint('[Onboarding] Error loading account data: $e');
      debugPrint('[Onboarding] Stack: $st');
      _debugErrorMessage = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _loadingAccountData = false;
        });
      }
    }
  }
  
  void _onStep1Changed() {
    if (_currentStep == 0) setState(() {});
  }
  
  void _onStep4Changed() {
    if (_currentStep == 3) setState(() {});
  }

  @override
  void dispose() {
    _purchaserNameController.removeListener(_onStep1Changed);
    _slotsController.removeListener(_onStep1Changed);
    _gbpUrlController.removeListener(_onStep4Changed);
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

  // ============ VALIDATION METHODS ============
  
  /// Step 1: Purchaser name (min 2 chars), slots (1-50 integer)
  bool _validateStep1() {
    final name = _purchaserNameController.text.trim();
    final slotsText = _slotsController.text.trim();
    final slots = int.tryParse(slotsText);
    
    if (name.length < 2) return false;
    if (slots == null || slots < 1 || slots > 50) return false;
    
    return true;
  }
  
  String? _getStep1Error() {
    final name = _purchaserNameController.text.trim();
    final slotsText = _slotsController.text.trim();
    final slots = int.tryParse(slotsText);
    
    if (name.isEmpty) return 'Please enter your name';
    if (name.length < 2) return 'Name must be at least 2 characters';
    if (slotsText.isEmpty) return 'Please enter number of wristband slots';
    if (slots == null) return 'Please enter a valid number';
    if (slots < 1) return 'You need at least 1 wristband slot';
    if (slots > 50) return 'Maximum 50 wristband slots allowed';
    
    return null;
  }
  
  /// Step 2: All wristbands have unique names (min 2 chars), count <= maxWristbands
  bool _validateStep2() {
    final names = _wristbandControllers
        .map((c) => c.text.trim().toLowerCase())
        .where((n) => n.isNotEmpty)
        .toList();
    
    // Must have at least 1 wristband
    if (names.isEmpty) return false;
    
    // Check each name is at least 2 chars
    for (var c in _wristbandControllers) {
      final name = c.text.trim();
      if (name.isNotEmpty && name.length < 2) return false;
    }
    
    // All rows must be filled
    for (var c in _wristbandControllers) {
      if (c.text.trim().isEmpty) return false;
    }
    
    // Check uniqueness
    final uniqueNames = names.toSet();
    if (uniqueNames.length != names.length) return false;
    
    return true;
  }
  
  String? _getStep2Error() {
    // Check if any row is empty
    for (int i = 0; i < _wristbandControllers.length; i++) {
      final name = _wristbandControllers[i].text.trim();
      if (name.isEmpty) {
        return 'Please fill in all wristband names';
      }
      if (name.length < 2) {
        return 'Wristband ${i + 1}: name must be at least 2 characters';
      }
    }
    
    // Check uniqueness
    final names = _wristbandControllers
        .map((c) => c.text.trim().toLowerCase())
        .toList();
    final seen = <String>{};
    for (int i = 0; i < names.length; i++) {
      if (seen.contains(names[i])) {
        return 'Duplicate wristband name: "${_wristbandControllers[i].text.trim()}"';
      }
      seen.add(names[i]);
    }
    
    if (_wristbandControllers.isEmpty) {
      return 'Please add at least one wristband';
    }
    
    return null;
  }
  
  /// Step 3: At least 1 team with name (min 2 chars), at least 2 members total (min 2 chars each), unique within team
  bool _validateStep3() {
    if (_teams.isEmpty) return false;
    
    int totalMembers = 0;
    
    for (var team in _teams) {
      final teamName = team.nameController.text.trim();
      if (teamName.length < 2) return false;
      
      final memberNames = <String>{};
      for (var mc in team.memberControllers) {
        final name = mc.text.trim();
        if (name.isNotEmpty) {
          if (name.length < 2) return false;
          // Check uniqueness within team (case-insensitive)
          if (memberNames.contains(name.toLowerCase())) return false;
          memberNames.add(name.toLowerCase());
          totalMembers++;
        }
      }
    }
    
    // Must have at least 2 members total
    if (totalMembers < 2) return false;
    
    return true;
  }
  
  String? _getStep3Error() {
    if (_teams.isEmpty) {
      return 'Please add at least one team';
    }
    
    for (int ti = 0; ti < _teams.length; ti++) {
      final team = _teams[ti];
      final teamName = team.nameController.text.trim();
      
      if (teamName.isEmpty) {
        return 'Please enter a name for Team ${ti + 1}';
      }
      if (teamName.length < 2) {
        return 'Team ${ti + 1}: name must be at least 2 characters';
      }
      
      // Check member names
      final memberNames = <String>{};
      for (int mi = 0; mi < team.memberControllers.length; mi++) {
        final name = team.memberControllers[mi].text.trim();
        if (name.isNotEmpty) {
          if (name.length < 2) {
            return 'Team ${ti + 1}, Member ${mi + 1}: name must be at least 2 characters';
          }
          if (memberNames.contains(name.toLowerCase())) {
            return 'Team ${ti + 1}: duplicate member name "$name"';
          }
          memberNames.add(name.toLowerCase());
        }
      }
    }
    
    // Count total members
    int totalMembers = 0;
    for (var team in _teams) {
      for (var mc in team.memberControllers) {
        if (mc.text.trim().isNotEmpty) totalMembers++;
      }
    }
    
    if (totalMembers < 2) {
      return 'You need at least 2 team members total';
    }
    
    return null;
  }
  
  /// Step 4: Valid URL, all wristbands assigned
  bool _validateStep4() {
    final url = _gbpUrlController.text.trim();
    
    // URL is required and must be valid format
    if (url.isEmpty) return false;
    if (!_isValidUrl(url)) return false;
    
    // All wristbands must be assigned
    final wristbandCount = _wristbandControllers
        .where((c) => c.text.trim().isNotEmpty)
        .length;
    
    if (wristbandCount == 0) return false;
    
    // Check that every wristband index is assigned
    for (int i = 0; i < _wristbandControllers.length; i++) {
      if (_wristbandControllers[i].text.trim().isNotEmpty) {
        final assignment = _wristbandAssignments[i];
        if (assignment == null || assignment.isEmpty) return false;
      }
    }
    
    return true;
  }
  
  String? _getStep4Error() {
    final url = _gbpUrlController.text.trim();
    
    if (url.isEmpty) {
      return 'Please enter your Google Business Profile URL';
    }
    if (!_isValidUrl(url)) {
      return 'Please enter a valid URL (e.g., https://business.google.com/...)';
    }
    
    final wristbandCount = _wristbandControllers
        .where((c) => c.text.trim().isNotEmpty)
        .length;
    
    if (wristbandCount == 0) {
      return 'No wristbands defined. Go back to Step 2';
    }
    
    final unassigned = _unassignedCount();
    if (unassigned > 0) {
      return 'Please assign all wristbands to team members ($unassigned unassigned)';
    }
    
    return null;
  }
  
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      // Only allow https URLs for security
      return uri.hasScheme && uri.scheme == 'https' && uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  bool _isCurrentStepValid() {
    // Block navigation while loading account data on Step 1
    if (_currentStep == 0 && _loadingAccountData) return false;
    
    switch (_currentStep) {
      case 0: return _validateStep1();
      case 1: return _validateStep2();
      case 2: return _validateStep3();
      case 3: return _validateStep4();
      default: return false;
    }
  }
  
  String? _getCurrentStepError() {
    switch (_currentStep) {
      case 0: return _getStep1Error();
      case 1: return _getStep2Error();
      case 2: return _getStep3Error();
      case 3: return _getStep4Error();
      default: return null;
    }
  }

  void _next() {
    if (_currentStep < 3) {
      // Validate current step
      if (!_isCurrentStepValid()) {
        final error = _getCurrentStepError();
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: AppColors.orange,
            ),
          );
        }
        setState(() {
          switch (_currentStep) {
            case 0: _step1Error = error; break;
            case 1: _step2Error = error; break;
            case 2: _step3Error = error; break;
          }
        });
        return;
      }
      
      // Clear error and proceed
      setState(() {
        switch (_currentStep) {
          case 0:
            _step1Error = null;
            // Store maxWristbands and sync wristband controllers
            final newMaxWristbands = int.tryParse(_slotsController.text.trim()) ?? 10;
            _maxWristbands = newMaxWristbands;
            
            // Sync wristband controllers to match maxWristbands
            if (_wristbandControllers.isEmpty) {
              // First time: initialize with maxWristbands empty controllers
              _wristbandControllers = List.generate(
                _maxWristbands,
                (_) => TextEditingController(),
              );
            } else if (_wristbandControllers.length > _maxWristbands) {
              // Reduce: dispose excess controllers
              for (int i = _maxWristbands; i < _wristbandControllers.length; i++) {
                _wristbandControllers[i].dispose();
              }
              _wristbandControllers = _wristbandControllers.sublist(0, _maxWristbands);
              // Clean up assignments for removed wristbands
              _wristbandAssignments.removeWhere((k, v) => k >= _maxWristbands);
            } else if (_wristbandControllers.length < _maxWristbands) {
              // Expand: add new empty controllers
              final needed = _maxWristbands - _wristbandControllers.length;
              for (int i = 0; i < needed; i++) {
                _wristbandControllers.add(TextEditingController());
              }
            }
            break;
          case 1: _step2Error = null; break;
          case 2: _step3Error = null; break;
        }
        _currentStep++;
      });
    }
  }

  void _back() {
    if (_currentStep > 0) {
      setState(() {
        // Clear current step error when going back
        switch (_currentStep) {
          case 1: _step1Error = null; break;
          case 2: _step2Error = null; break;
          case 3: _step3Error = null; break;
        }
        _currentStep--;
      });
    }
  }

  Future<void> _finishSetup() async {
    if (_saving) return;
    
    // Validate Step 4 before finishing
    if (!_validateStep4()) {
      final error = _getStep4Error();
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.orange,
          ),
        );
        setState(() => _step4Error = error);
      }
      return;
    }
    
    setState(() {
      _saving = true;
      _step4Error = null;
    });

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
        // ========== TEMPORARY DEBUG CARD (REMOVE AFTER VERIFICATION) ==========
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.yellow.shade100,
            border: Border.all(color: Colors.orange, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '⚠️ TEMPORARY DEBUG (REMOVE AFTER VERIFICATION)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red),
              ),
              const Divider(),
              const Text('DEBUG AUTH:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              Text('• uid: ${_debugAuthUid ?? "not set"}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              Text('• email: ${_debugAuthEmail ?? "not set"}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              const Text('DEBUG FIRESTORE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              Text('• path: ${_debugFirestorePath ?? "not set"}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              Text('• docExists: ${_debugDocExists ?? "not set"}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              Text('• docKeys: ${_debugDocKeys?.join(", ") ?? "not set"}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              const Text('DEBUG RAW SLOT FIELDS (from Firestore):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              Text('• slotsPurchasedTotal: ${_debugRawData?['slotsPurchasedTotal'] ?? "MISSING"}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              Text('• slotsRefundedTotal: ${_debugRawData?['slotsRefundedTotal'] ?? "MISSING"}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              Text('• slotsNet: ${_debugRawData?['slotsNet'] ?? "MISSING"}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              Text('• slotsAvailable: ${_debugRawData?['slotsAvailable'] ?? "MISSING"}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              Text('• slotsUsed: ${_debugRawData?['slotsUsed'] ?? "MISSING"}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              const Text('DEBUG NAME FIELDS (from Firestore):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              Text('• displayName: ${_debugRawData?['displayName'] ?? "MISSING"}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              Text('• firstName: ${_debugRawData?['firstName'] ?? "MISSING"}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              Text('• lastName: ${_debugRawData?['lastName'] ?? "MISSING"}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              const Text('DEBUG IDENTITY FIELDS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              Text('• shopifyCustomerId: ${_debugRawData?['shopifyCustomerId'] ?? "MISSING"}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              Text('• shopifyEmail: ${_debugRawData?['shopifyEmail'] ?? "MISSING"}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              Text('• planStatus: ${_debugRawData?['planStatus'] ?? "MISSING"}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              const Text('EXTRACTED VALUES FOR PREFILL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              Text('• purchaserName: ${_debugPurchaserNameValue ?? "not set"}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              Text('• slotCount: ${_debugSlotCountValue ?? "not set"}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              const Text('DEBUG STATE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              Text('• loading: $_loadingAccountData', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              Text('• error: ${_debugErrorMessage ?? "none"}', style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: _debugErrorMessage != null ? Colors.red : Colors.black)),
              const SizedBox(height: 8),
              const Text('CONTROLLER VALUES:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              Text('• _purchaserNameController.text: "${_purchaserNameController.text}"', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              Text('• _slotsController.text: "${_slotsController.text}"', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
            ],
          ),
        ),
        // ========== END DEBUG CARD ==========
        
        if (_loadingAccountData) ...[
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading your account data...',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ] else ...[
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
            helperText: "This determines how many wristband inputs you'll start with (1-50). You can use fewer than your purchased total.",
          ),
          // Show inline error if present
          if (_step1Error != null) ...[
            const SizedBox(height: 16),
            _buildInlineError(_step1Error!),
          ],
        ],
      ],
    );
  }

  Widget _buildStep2() {
    final canAddMore = _wristbandControllers.length < _maxWristbands;
    final canRemove = _wristbandControllers.length > 1;
    
    return _OnboardingCard(
      title: 'Define Your Wristbands',
      description: "Now, give your wristbands custom names. These will help you identify them easily later. Each wristband starts unassigned.",
      children: [
        // Show count indicator
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You have $_maxWristbands slot${_maxWristbands == 1 ? '' : 's'} available. Currently using ${_wristbandControllers.length}.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
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
                      onChanged: (_) => setState(() {}),
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
                  if (canRemove)
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
        if (canAddMore) ...[
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
                if (_wristbandControllers.length < _maxWristbands) {
                  setState(() {
                    _wristbandControllers.add(TextEditingController());
                  });
                }
              },
              icon: const Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
              label: Text(
                'Add Another Wristband',
                style: AppTextStyles.button.copyWith(color: AppColors.primary),
              ),
            ),
          ),
        ],
        // Show inline error if present
        if (_step2Error != null) ...[
          const SizedBox(height: 16),
          _buildInlineError(_step2Error!),
        ],
      ],
    );
  }
  
  Widget _buildInlineError(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.error_outline, color: AppColors.orange, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    // Count total members for display
    int totalMembers = 0;
    for (var team in _teams) {
      for (var mc in team.memberControllers) {
        if (mc.text.trim().isNotEmpty) totalMembers++;
      }
    }
    
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
                  'You currently have $totalMembers member${totalMembers == 1 ? '' : 's'} (minimum 2 required).',
                  style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ...List.generate(_teams.length, (ti) => _buildTeamEditor(ti)),
        // Show inline error if present
        if (_step3Error != null) ...[
          const SizedBox(height: 8),
          _buildInlineError(_step3Error!),
        ],
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
              onChanged: (_) => setState(() {}),
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
                        onChanged: (_) => setState(() {}),
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
                    'You still have $unassigned wristband(s) unassigned. All must be assigned to continue.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.orange, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
        // Show inline error if present
        if (_step4Error != null) ...[
          const SizedBox(height: 16),
          _buildInlineError(_step4Error!),
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
              child: Builder(
                builder: (context) {
                  final isValid = _isCurrentStepValid();
                  final isDisabled = _saving;
                  
                  return Opacity(
                    opacity: isValid ? 1.0 : 0.6,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: isValid
                              ? [AppColors.primary, AppColors.primary.withOpacity(0.9)]
                              : [AppColors.textMuted, AppColors.textMuted.withOpacity(0.8)],
                        ),
                        boxShadow: isValid
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : [],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed: isDisabled
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
                  );
                },
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
