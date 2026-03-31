import 'package:flutter/material.dart';

// ─── Primary disaster status (maps to ESP32 bitmask bits [5:4]) ──────

enum DisasterStatus {
  injured, // Yaralıyım  — bitmask 0b00
  trapped, // Mahsurum    — bitmask 0b01
  safe,    // Güvendeyim  — bitmask 0b10
}

extension DisasterStatusX on DisasterStatus {
  String get label {
    switch (this) {
      case DisasterStatus.injured:
        return 'Yaralıyım';
      case DisasterStatus.trapped:
        return 'Mahsurum';
      case DisasterStatus.safe:
        return 'Güvendeyim';
    }
  }

  String get subtitle {
    switch (this) {
      case DisasterStatus.injured:
        return 'Tıbbi yardıma ihtiyacım var';
      case DisasterStatus.trapped:
        return 'Sıkıştım, çıkamıyorum';
      case DisasterStatus.safe:
        return 'Güvendeyim, durumum iyi';
    }
  }

  IconData get icon {
    switch (this) {
      case DisasterStatus.injured:
        return Icons.healing;
      case DisasterStatus.trapped:
        return Icons.warning_amber_rounded;
      case DisasterStatus.safe:
        return Icons.shield;
    }
  }

  Color get color {
    switch (this) {
      case DisasterStatus.injured:
        return const Color(0xFFEF4444);
      case DisasterStatus.trapped:
        return const Color(0xFFF59E0B);
      case DisasterStatus.safe:
        return const Color(0xFF10B981);
    }
  }

  int get baseScore {
    switch (this) {
      case DisasterStatus.injured:
        return 80;
      case DisasterStatus.trapped:
        return 60;
      case DisasterStatus.safe:
        return 10;
    }
  }

  int get bitmaskValue {
    switch (this) {
      case DisasterStatus.injured:
        return 0x00;
      case DisasterStatus.trapped:
        return 0x01;
      case DisasterStatus.safe:
        return 0x02;
    }
  }
}

// ─── Injury chips (Byte 1 flags) ────────────────────────────────────

enum InjuryChip {
  bleeding,      // bit 7 — Kanama
  fracture,      // bit 6 — Kırık
  breathingIssue,// bit 5 — Nefes problemi
  headInjury,    // bit 4 — Kafa travması
  burn,          // bit 3 — Yanık
  crush,         // bit 2 — Ezilme
}

extension InjuryChipX on InjuryChip {
  String get label {
    switch (this) {
      case InjuryChip.bleeding:
        return 'Kanama';
      case InjuryChip.fracture:
        return 'Kırık';
      case InjuryChip.breathingIssue:
        return 'Nefes Problemi';
      case InjuryChip.headInjury:
        return 'Kafa Travması';
      case InjuryChip.burn:
        return 'Yanık';
      case InjuryChip.crush:
        return 'Ezilme';
    }
  }

  IconData get icon {
    switch (this) {
      case InjuryChip.bleeding:
        return Icons.water_drop;
      case InjuryChip.fracture:
        return Icons.accessibility_new;
      case InjuryChip.breathingIssue:
        return Icons.air;
      case InjuryChip.headInjury:
        return Icons.psychology;
      case InjuryChip.burn:
        return Icons.local_fire_department;
      case InjuryChip.crush:
        return Icons.compress;
    }
  }

  int get scoreModifier {
    switch (this) {
      case InjuryChip.breathingIssue:
        return 30;
      case InjuryChip.headInjury:
        return 25;
      case InjuryChip.bleeding:
        return 20;
      case InjuryChip.crush:
        return 15;
      case InjuryChip.burn:
        return 12;
      case InjuryChip.fracture:
        return 10;
    }
  }

  int get bitPosition {
    switch (this) {
      case InjuryChip.bleeding:
        return 7;
      case InjuryChip.fracture:
        return 6;
      case InjuryChip.breathingIssue:
        return 5;
      case InjuryChip.headInjury:
        return 4;
      case InjuryChip.burn:
        return 3;
      case InjuryChip.crush:
        return 2;
    }
  }
}

// ─── Situation chips (Byte 2 flags) ─────────────────────────────────

enum SituationChip {
  underRubble,   // bit 7 — Enkaz altında
  noExit,        // bit 6 — Çıkış yok
  gasLeak,       // bit 5 — Gaz kaçağı
  fire,          // bit 4 — Yangın
  flooding,      // bit 3 — Su baskını
  structuralRisk,// bit 2 — Yapısal risk
}

extension SituationChipX on SituationChip {
  String get label {
    switch (this) {
      case SituationChip.underRubble:
        return 'Enkaz Altında';
      case SituationChip.noExit:
        return 'Çıkış Yok';
      case SituationChip.gasLeak:
        return 'Gaz Kaçağı';
      case SituationChip.fire:
        return 'Yangın';
      case SituationChip.flooding:
        return 'Su Baskını';
      case SituationChip.structuralRisk:
        return 'Yapısal Risk';
    }
  }

  IconData get icon {
    switch (this) {
      case SituationChip.underRubble:
        return Icons.foundation;
      case SituationChip.noExit:
        return Icons.no_meeting_room;
      case SituationChip.gasLeak:
        return Icons.gas_meter;
      case SituationChip.fire:
        return Icons.local_fire_department;
      case SituationChip.flooding:
        return Icons.water;
      case SituationChip.structuralRisk:
        return Icons.dangerous;
    }
  }

  int get scoreModifier {
    switch (this) {
      case SituationChip.gasLeak:
        return 20;
      case SituationChip.fire:
        return 20;
      case SituationChip.underRubble:
        return 15;
      case SituationChip.flooding:
        return 10;
      case SituationChip.structuralRisk:
        return 10;
      case SituationChip.noExit:
        return 8;
    }
  }

  int get bitPosition {
    switch (this) {
      case SituationChip.underRubble:
        return 7;
      case SituationChip.noExit:
        return 6;
      case SituationChip.gasLeak:
        return 5;
      case SituationChip.fire:
        return 4;
      case SituationChip.flooding:
        return 3;
      case SituationChip.structuralRisk:
        return 2;
    }
  }
}

// ─── Needs chips (Byte 3 flags) ─────────────────────────────────────

enum NeedChip {
  water,         // bit 7 — Su
  food,          // bit 6 — Yiyecek
  medical,       // bit 5 — Tıbbi yardım
  warmth,        // bit 4 — Isınma
  light,         // bit 3 — Aydınlatma
  communication, // bit 2 — İletişim
}

extension NeedChipX on NeedChip {
  String get label {
    switch (this) {
      case NeedChip.water:
        return 'Su';
      case NeedChip.food:
        return 'Yiyecek';
      case NeedChip.medical:
        return 'Tıbbi Yardım';
      case NeedChip.warmth:
        return 'Isınma';
      case NeedChip.light:
        return 'Aydınlatma';
      case NeedChip.communication:
        return 'İletişim';
    }
  }

  IconData get icon {
    switch (this) {
      case NeedChip.water:
        return Icons.water_drop_outlined;
      case NeedChip.food:
        return Icons.restaurant;
      case NeedChip.medical:
        return Icons.medical_services;
      case NeedChip.warmth:
        return Icons.thermostat;
      case NeedChip.light:
        return Icons.flashlight_on;
      case NeedChip.communication:
        return Icons.cell_tower;
    }
  }

  int get bitPosition {
    switch (this) {
      case NeedChip.water:
        return 7;
      case NeedChip.food:
        return 6;
      case NeedChip.medical:
        return 5;
      case NeedChip.warmth:
        return 4;
      case NeedChip.light:
        return 3;
      case NeedChip.communication:
        return 2;
    }
  }
}

// ─── People chips (Byte 4 flags) ────────────────────────────────────

enum PeopleChip {
  alone,          // bit 7 — Tek başıma
  withChildren,   // bit 6 — Çocuklu
  withElderly,    // bit 5 — Yaşlı var
  withDisabled,   // bit 4 — Engelli var
  pregnant,       // bit 3 — Hamile var
  multipleInjured,// bit 2 — Birden fazla yaralı
}

extension PeopleChipX on PeopleChip {
  String get label {
    switch (this) {
      case PeopleChip.alone:
        return 'Tek Başıma';
      case PeopleChip.withChildren:
        return 'Çocuklu';
      case PeopleChip.withElderly:
        return 'Yaşlı Var';
      case PeopleChip.withDisabled:
        return 'Engelli Var';
      case PeopleChip.pregnant:
        return 'Hamile Var';
      case PeopleChip.multipleInjured:
        return 'Çok Yaralı';
    }
  }

  IconData get icon {
    switch (this) {
      case PeopleChip.alone:
        return Icons.person;
      case PeopleChip.withChildren:
        return Icons.child_care;
      case PeopleChip.withElderly:
        return Icons.elderly;
      case PeopleChip.withDisabled:
        return Icons.accessible;
      case PeopleChip.pregnant:
        return Icons.pregnant_woman;
      case PeopleChip.multipleInjured:
        return Icons.groups;
    }
  }

  int get scoreModifier {
    switch (this) {
      case PeopleChip.withChildren:
        return 15;
      case PeopleChip.pregnant:
        return 15;
      case PeopleChip.withElderly:
        return 10;
      case PeopleChip.withDisabled:
        return 10;
      case PeopleChip.multipleInjured:
        return 10;
      case PeopleChip.alone:
        return 0;
    }
  }

  int get bitPosition {
    switch (this) {
      case PeopleChip.alone:
        return 7;
      case PeopleChip.withChildren:
        return 6;
      case PeopleChip.withElderly:
        return 5;
      case PeopleChip.withDisabled:
        return 4;
      case PeopleChip.pregnant:
        return 3;
      case PeopleChip.multipleInjured:
        return 2;
    }
  }
}

// ─── Triage categories ──────────────────────────────────────────────

enum TriageCategory {
  green,  // 0–30   — Low priority
  yellow, // 31–60  — Delayed
  orange, // 61–120 — Urgent
  red,    // 121+   — Immediate
}

extension TriageCategoryX on TriageCategory {
  String get label {
    switch (this) {
      case TriageCategory.green:
        return 'YEŞİL — Düşük Öncelik';
      case TriageCategory.yellow:
        return 'SARI — Gecikmeli';
      case TriageCategory.orange:
        return 'TURUNCU — Acil';
      case TriageCategory.red:
        return 'KIRMIZI — Derhal';
    }
  }

  Color get color {
    switch (this) {
      case TriageCategory.green:
        return const Color(0xFF10B981);
      case TriageCategory.yellow:
        return const Color(0xFFF59E0B);
      case TriageCategory.orange:
        return const Color(0xFFF97316);
      case TriageCategory.red:
        return const Color(0xFFEF4444);
    }
  }

  static TriageCategory fromScore(int score) {
    if (score <= 30) return TriageCategory.green;
    if (score <= 60) return TriageCategory.yellow;
    if (score <= 120) return TriageCategory.orange;
    return TriageCategory.red;
  }
}

// ─── Priority level for v2 packet protocol ──────────────────────────

enum PriorityLevel {
  critical, // triage score >= 80
  high,     // triage score >= 50
  medium,   // triage score >= 20
  low,      // triage score < 20
  ;

  static PriorityLevel fromTriageScore(int score) {
    if (score >= 80) return PriorityLevel.critical;
    if (score >= 50) return PriorityLevel.high;
    if (score >= 20) return PriorityLevel.medium;
    return PriorityLevel.low;
  }

  int get bitmask {
    switch (this) {
      case PriorityLevel.low:      return 0x00;
      case PriorityLevel.medium:   return 0x01;
      case PriorityLevel.high:     return 0x02;
      case PriorityLevel.critical: return 0x03;
    }
  }

  static PriorityLevel fromBitmask(int bits) {
    switch (bits & 0x03) {
      case 0x03: return PriorityLevel.critical;
      case 0x02: return PriorityLevel.high;
      case 0x01: return PriorityLevel.medium;
      default:   return PriorityLevel.low;
    }
  }
}
