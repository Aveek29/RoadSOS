import 'package:flutter/material.dart';
import 'package:roadsos_app/ui/theme.dart';
import 'package:roadsos_app/ui/components/qr_code_painter.dart';
import 'package:roadsos_app/services/medical_id_service.dart';

class MedicalIDScreen extends StatefulWidget {
  final bool isReadOnly;

  const MedicalIDScreen({
    super.key,
    this.isReadOnly = false,
  });

  @override
  State<MedicalIDScreen> createState() => _MedicalIDScreenState();
}

class _MedicalIDScreenState extends State<MedicalIDScreen>
    with SingleTickerProviderStateMixin {
  final _service = MedicalIDService();
  bool _isEditing = false;
  bool _qrExpanded = true;

  late AnimationController _animController;
  late Animation<double> _fadeIn;

  // Form key and controllers
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _genderController;
  late TextEditingController _bloodController;
  late TextEditingController _conditionsController;
  late TextEditingController _allergiesController;
  late TextEditingController _medicationsController;
  late TextEditingController _addressController;
  late TextEditingController _hospitalController;

  late TextEditingController _c1NameController;
  late TextEditingController _c1RelationController;
  late TextEditingController _c1PhoneController;
  late TextEditingController _c2NameController;
  late TextEditingController _c2RelationController;
  late TextEditingController _c2PhoneController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _initControllers();
  }

  @override
  void dispose() {
    _animController.dispose();
    _disposeControllers();
    super.dispose();
  }

  void _initControllers() {
    final p = _service.profile;
    _nameController = TextEditingController(text: p.fullName);
    _ageController = TextEditingController(text: p.age.toString());
    _genderController = TextEditingController(text: p.gender);
    _bloodController = TextEditingController(text: p.bloodGroup);
    _conditionsController = TextEditingController(text: p.conditions);
    _allergiesController = TextEditingController(text: p.allergies);
    _medicationsController = TextEditingController(text: p.medications);
    _addressController = TextEditingController(text: p.address);
    _hospitalController = TextEditingController(text: p.preferredHospital);

    final c1 = p.contacts.isNotEmpty
        ? p.contacts[0]
        : EmergencyContact(name: '', relation: '', phone: '');
    final c2 = p.contacts.length > 1
        ? p.contacts[1]
        : EmergencyContact(name: '', relation: '', phone: '');

    _c1NameController = TextEditingController(text: c1.name);
    _c1RelationController = TextEditingController(text: c1.relation);
    _c1PhoneController = TextEditingController(text: c1.phone);
    _c2NameController = TextEditingController(text: c2.name);
    _c2RelationController = TextEditingController(text: c2.relation);
    _c2PhoneController = TextEditingController(text: c2.phone);
  }

  void _disposeControllers() {
    for (final c in [
      _nameController, _ageController, _genderController, _bloodController,
      _conditionsController, _allergiesController, _medicationsController,
      _addressController, _hospitalController,
      _c1NameController, _c1RelationController, _c1PhoneController,
      _c2NameController, _c2RelationController, _c2PhoneController,
    ]) {
      c.dispose();
    }
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      final updated = MedicalIDModel(
        fullName: _nameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()) ?? 24,
        gender: _genderController.text.trim(),
        bloodGroup: _bloodController.text.trim(),
        conditions: _conditionsController.text.trim(),
        allergies: _allergiesController.text.trim(),
        medications: _medicationsController.text.trim(),
        address: _addressController.text.trim(),
        preferredHospital: _hospitalController.text.trim(),
        contacts: [
          EmergencyContact(
            name: _c1NameController.text.trim(),
            relation: _c1RelationController.text.trim(),
            phone: _c1PhoneController.text.trim(),
          ),
          EmergencyContact(
            name: _c2NameController.text.trim(),
            relation: _c2RelationController.text.trim(),
            phone: _c2PhoneController.text.trim(),
          ),
        ],
      );

      setState(() {
        _service.updateProfile(updated);
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medical ID saved.', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: RoadSoSColors.rescueTeal,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        final profile = _service.profile;
        return Scaffold(
          backgroundColor: const Color(0xFF0B1020),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Text(
              widget.isReadOnly ? 'MEDICAL ID EMERGENCY CARD' : 'Medical ID',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            centerTitle: true,
            actions: [
              if (!widget.isReadOnly)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: _isEditing
                          ? RoadSoSColors.critical
                          : RoadSoSColors.rescueTeal,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_isEditing) _initControllers();
                        _isEditing = !_isEditing;
                      });
                    },
                    icon: Icon(_isEditing ? Icons.close : Icons.edit_rounded, size: 16),
                    label: Text(
                      _isEditing ? 'Cancel' : 'Edit',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                )
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0B1020), Color(0xFF070B16)],
              ),
            ),
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeIn,
                child: _isEditing ? _buildEditorForm() : _buildViewer(profile),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  //  VIEWER
  // ─────────────────────────────────────────────

  Widget _buildViewer(MedicalIDModel profile) {
    final String qrPayload =
        'Name:${profile.fullName}|Age:${profile.age}|Gender:${profile.gender}|Blood:${profile.bloodGroup}|Conditions:${profile.conditions}|Allergies:${profile.allergies}|Meds:${profile.medications}|Contacts:${profile.contacts.map((e) => '${e.name}(${e.phone})').join(',')}';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Identity Header Card ──────────────────────────
          _buildIdentityHeader(profile),
          const SizedBox(height: 20),

          // ── Section: Critical Data ────────────────────────
          _sectionLabel('CRITICAL EMERGENCY DATA', RoadSoSColors.critical),
          const SizedBox(height: 10),

          _buildInfoCard(
            icon: Icons.bloodtype_rounded,
            label: 'BLOOD GROUP',
            value: profile.bloodGroup,
            accentColor: RoadSoSColors.critical,
          ),
          const SizedBox(height: 10),
          _buildInfoCard(
            icon: Icons.warning_amber_rounded,
            label: 'ALLERGIES',
            value: profile.allergies.isNotEmpty
                ? profile.allergies
                : 'No Known Allergies',
            accentColor: RoadSoSColors.warning,
          ),
          const SizedBox(height: 10),
          _buildInfoCard(
            icon: Icons.healing_rounded,
            label: 'MEDICAL CONDITIONS',
            value: profile.conditions.isNotEmpty
                ? profile.conditions
                : 'No Chronic Conditions',
            accentColor: RoadSoSColors.rescueTeal,
          ),
          const SizedBox(height: 10),
          _buildInfoCard(
            icon: Icons.medication_liquid_rounded,
            label: 'ACTIVE MEDICATIONS',
            value: profile.medications.isNotEmpty
                ? profile.medications
                : 'No Active Medications',
            accentColor: RoadSoSColors.volunteerPurple,
          ),
          const SizedBox(height: 10),
          _buildInfoCard(
            icon: Icons.local_hospital_rounded,
            label: 'PREFERRED HOSPITAL',
            value: profile.preferredHospital,
            accentColor: const Color(0xFF38BDF8),
          ),
          const SizedBox(height: 10),
          _buildInfoCard(
            icon: Icons.home_rounded,
            label: 'HOME ADDRESS',
            value: profile.address,
            accentColor: Colors.white38,
          ),
          const SizedBox(height: 24),

          // ── Section: Emergency Contacts ───────────────────
          _sectionLabel('EMERGENCY CONTACTS', RoadSoSColors.rescueTeal),
          const SizedBox(height: 10),
          _buildContactsCard(profile),
          const SizedBox(height: 24),

          // ── Section: Paramedic QR Card ────────────────────
          _sectionLabel('PARAMEDIC SCAN QR', RoadSoSColors.volunteerPurple),
          const SizedBox(height: 10),
          _buildQrSection(qrPayload),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Identity Header ──────────────────────────────────
  Widget _buildIdentityHeader(MedicalIDModel profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            RoadSoSColors.critical.withOpacity(0.18),
            RoadSoSColors.redDim.withOpacity(0.4),
          ],
        ),
        border: Border.all(color: RoadSoSColors.critical.withOpacity(0.25), width: 1.2),
      ),
      child: Row(
        children: [
          // Avatar / Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: RoadSoSColors.critical.withOpacity(0.15),
              border: Border.all(color: RoadSoSColors.critical.withOpacity(0.5), width: 2),
            ),
            child: const Icon(
              Icons.medical_services_rounded,
              color: RoadSoSColors.critical,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Age ${profile.age}  ·  ${profile.gender}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: RoadSoSColors.critical.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: RoadSoSColors.critical.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: RoadSoSColors.critical,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Medical ID Active',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: RoadSoSColors.critical,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Info Card ────────────────────────────────────────
  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF111828),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withOpacity(0.35),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Emergency Contacts Card ──────────────────────────
  Widget _buildContactsCard(MedicalIDModel profile) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111828),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: List.generate(profile.contacts.length, (index) {
          final contact = profile.contacts[index];
          final isLast = index == profile.contacts.length - 1;
          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: RoadSoSColors.rescueTeal.withOpacity(0.12),
                    border: Border.all(color: RoadSoSColors.rescueTeal.withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: RoadSoSColors.rescueTeal,
                    size: 20,
                  ),
                ),
                title: Text(
                  contact.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${contact.relation}  ·  ${contact.phone}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.45),
                  ),
                ),
                trailing: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: RoadSoSColors.rescueTeal.withOpacity(0.12),
                  ),
                  child: const Icon(
                    Icons.call_rounded,
                    color: RoadSoSColors.rescueTeal,
                    size: 18,
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: Colors.white.withOpacity(0.06),
                  indent: 72,
                  endIndent: 16,
                ),
            ],
          );
        }),
      ),
    );
  }

  // ── QR Section ───────────────────────────────────────
  Widget _buildQrSection(String qrPayload) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111828),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: RoadSoSColors.volunteerPurple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: RoadSoSColors.volunteerPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EMERGENCY QR CODE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Scan to access medical data instantly',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF7B8DB0),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _qrExpanded = !_qrExpanded),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: RoadSoSColors.volunteerPurple.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: RoadSoSColors.volunteerPurple.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _qrExpanded ? 'Hide' : 'Show',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: RoadSoSColors.volunteerPurple,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _qrExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: RoadSoSColors.volunteerPurple,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // QR Body
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _qrExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                const SizedBox(height: 20),
                // QR Code centered in white card
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: RoadSoSColors.volunteerPurple.withOpacity(0.2),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: QRCodeWidget(
                      data: qrPayload,
                      size: 160.0,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Instruction row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 12,
                      color: Colors.white.withOpacity(0.35),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Responders can scan this to access your\nmedical profile instantly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.35),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Data payload preview chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildDataChip('Blood: ${_service.profile.bloodGroup}',
                        RoadSoSColors.critical),
                    _buildDataChip(
                        'Allergies included', RoadSoSColors.warning),
                    _buildDataChip(
                        'Meds included', RoadSoSColors.volunteerPurple),
                    _buildDataChip(
                        '${_service.profile.contacts.length} Contacts',
                        RoadSoSColors.rescueTeal),
                  ],
                ),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildDataChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, Color accentColor) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white.withOpacity(0.4),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  EDITOR FORM
  // ─────────────────────────────────────────────

  Widget _buildEditorForm() {
    return Form(
      key: _formKey,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          _editorSectionHeader('PERSONAL IDENTIFICATION', Icons.person_rounded,
              RoadSoSColors.rescueTeal),
          const SizedBox(height: 12),
          _buildField('Full Name', _nameController, Icons.badge_outlined),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _buildField('Age', _ageController,
                      Icons.cake_outlined, isNumeric: true)),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildField(
                      'Gender', _genderController, Icons.wc_outlined)),
            ],
          ),
          const SizedBox(height: 20),

          _editorSectionHeader('CLINICAL TELEMETRY', Icons.biotech_outlined,
              RoadSoSColors.critical),
          const SizedBox(height: 12),
          _buildField(
              'Blood Group', _bloodController, Icons.bloodtype_outlined),
          const SizedBox(height: 10),
          _buildField('Medical Conditions', _conditionsController,
              Icons.healing_outlined,
              maxLines: 2),
          const SizedBox(height: 10),
          _buildField(
              'Known Allergies', _allergiesController, Icons.warning_outlined,
              maxLines: 2),
          const SizedBox(height: 10),
          _buildField('Active Medications', _medicationsController,
              Icons.medication_outlined,
              maxLines: 2),
          const SizedBox(height: 10),
          _buildField('Home Address', _addressController, Icons.home_outlined,
              maxLines: 2),
          const SizedBox(height: 10),
          _buildField('Preferred Hospital', _hospitalController,
              Icons.local_hospital_outlined),
          const SizedBox(height: 20),

          _editorSectionHeader('EMERGENCY CONTACTS', Icons.contacts_outlined,
              RoadSoSColors.warning),
          const SizedBox(height: 12),
          _buildContactBlock(
              'Contact 1', _c1NameController, _c1RelationController, _c1PhoneController),
          const SizedBox(height: 12),
          _buildContactBlock(
              'Contact 2', _c2NameController, _c2RelationController, _c2PhoneController),
          const SizedBox(height: 28),

          // Save button
          SizedBox(
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: RoadSoSColors.rescueTeal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _saveForm,
              child: const Text(
                'SAVE MEDICAL PROFILE',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _editorSectionHeader(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isNumeric = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: Colors.white38),
        alignLabelWithHint: true,
        filled: true,
        fillColor: const Color(0xFF111828),
        labelStyle: const TextStyle(color: Color(0xFF7B8DB0), fontSize: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RoadSoSColors.rescueTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RoadSoSColors.critical),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RoadSoSColors.critical, width: 1.5),
        ),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Required field' : null,
    );
  }

  Widget _buildContactBlock(
    String header,
    TextEditingController nameC,
    TextEditingController relationC,
    TextEditingController phoneC,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111828),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 10),
          _buildField('Full Name', nameC, Icons.person_outline),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _buildField('Relation', relationC, Icons.people_outline)),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildField(
                      'Phone', phoneC, Icons.phone_outlined,
                      isNumeric: false)),
            ],
          ),
        ],
      ),
    );
  }
}
