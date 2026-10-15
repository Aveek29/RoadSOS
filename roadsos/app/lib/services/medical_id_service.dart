import 'package:flutter/material.dart';

class EmergencyContact {
  String name;
  String relation;
  String phone;

  EmergencyContact({
    required this.name,
    required this.relation,
    required this.phone,
  });

  Map<String, String> toMap() {
    return {
      'name': name,
      'relation': relation,
      'phone': phone,
    };
  }

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      name: map['name'] ?? '',
      relation: map['relation'] ?? '',
      phone: map['phone'] ?? '',
    );
  }
}

class MedicalIDModel {
  String fullName;
  int age;
  String gender;
  String bloodGroup;
  String conditions;
  String allergies;
  String medications;
  String address;
  String preferredHospital;
  List<EmergencyContact> contacts;

  MedicalIDModel({
    required this.fullName,
    required this.age,
    required this.gender,
    required this.bloodGroup,
    required this.conditions,
    required this.allergies,
    required this.medications,
    required this.address,
    required this.preferredHospital,
    required this.contacts,
  });

  MedicalIDModel copyWith({
    String? fullName,
    int? age,
    String? gender,
    String? bloodGroup,
    String? conditions,
    String? allergies,
    String? medications,
    String? address,
    String? preferredHospital,
    List<EmergencyContact>? contacts,
  }) {
    return MedicalIDModel(
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      conditions: conditions ?? this.conditions,
      allergies: allergies ?? this.allergies,
      medications: medications ?? this.medications,
      address: address ?? this.address,
      preferredHospital: preferredHospital ?? this.preferredHospital,
      contacts: contacts ?? this.contacts,
    );
  }
}

class MedicalIDService extends ChangeNotifier {
  static final MedicalIDService _instance = MedicalIDService._internal();
  factory MedicalIDService() => _instance;
  MedicalIDService._internal();

  // Current Medical ID data instance (Default demo values)
  MedicalIDModel _profile = MedicalIDModel(
    fullName: 'Daksh Harrington',
    age: 24,
    gender: 'Male',
    bloodGroup: 'O Positive (O+)',
    conditions: 'Mild Exercise-Induced Asthma',
    allergies: 'Penicillin, Tree Nuts',
    medications: 'Albuterol Inhaler (PRN), Cetirizine 10mg',
    address: 'Team Harrington HQ, IIT Madras, Chennai, Tamil Nadu',
    preferredHospital: 'Fortis Malar Hospital, Adyar',
    contacts: [
      EmergencyContact(name: 'Arjun Kumar', relation: 'Father', phone: '+919876543210'),
      EmergencyContact(name: 'Sita Kumar', relation: 'Mother', phone: '+918765432109'),
    ],
  );

  MedicalIDModel get profile => _profile;

  void updateProfile(MedicalIDModel newProfile) {
    _profile = newProfile;
    notifyListeners();
  }
}
