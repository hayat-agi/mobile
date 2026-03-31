// lib/features/disaster_mode/services/pfa_message_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart'; // VoidCallback
import '../data/pfa_messages.dart';

class PFAMessageService {
  static final PFAMessageService _instance = PFAMessageService._internal();
  factory PFAMessageService() => _instance;
  PFAMessageService._internal();

  Timer? _noResponseTimer;

  // ── Keyword lists (Turkish, lowercase) ──────────────────────────────

  static const _panicKeywords = [
    'nefes',
    'nefes alamıyorum',
    'boğuluyorum',
    'bayılacağım',
    'kalp',
    'titriyor',
    'titriyorum',
    'çok kötü',
    'panik',
    'korku',
    'korkuyorum',
    'dayanamıyorum',
  ];

  static const _hopelessnessKeywords = [
    'kurtulamam',
    'kurtulamayacağım',
    'bitti',
    'her şey bitti',
    'umut',
    'umudum kalmadı',
    'fayda yok',
    'boşuna',
    'ölüyorum',
    'ölecek',
    'anlamsız',
  ];

  static const _lonelinessKeywords = [
    'yalnız',
    'yalnızım',
    'kimse',
    'kimse yok',
    'gelmiyor',
    'terk',
    'unutulduk',
    'unutuldum',
    'bana ne oldu',
  ];

  static const _painTrappedKeywords = [
    'ağrı',
    'acı',
    'sıkıştım',
    'sıkışık',
    'çıkamıyorum',
    'hareket edemiyorum',
    'kırık',
    'kan',
    'ezildi',
  ];

  static const _uncertaintyKeywords = [
    'bilmiyorum',
    'ne oluyor',
    'dışarda',
    'haber',
    'haberim yok',
    'ne zaman',
    'söyleyin',
    'bilgi',
    'bana söyleyin',
  ];

  /// Detects which PFA category a message belongs to.
  /// Returns null if no trigger keywords found.
  PfaCategory? detectCategory(String messageText) {
    final lower = messageText.toLowerCase();
    if (_containsAny(lower, _panicKeywords)) return PfaCategory.panicBreathing;
    if (_containsAny(lower, _hopelessnessKeywords)) return PfaCategory.hopelessness;
    if (_containsAny(lower, _lonelinessKeywords)) return PfaCategory.loneliness;
    if (_containsAny(lower, _painTrappedKeywords)) return PfaCategory.painTrapped;
    if (_containsAny(lower, _uncertaintyKeywords)) return PfaCategory.uncertainty;
    return null;
  }

  PfaCategory detectCategoryWithRisk(String messageText, {int riskScore = 0}) {
    final lower = messageText.toLowerCase();
    final categoryScores = <PfaCategory, int>{
      PfaCategory.panicBreathing: _matchCount(lower, _panicKeywords),
      PfaCategory.hopelessness: _matchCount(lower, _hopelessnessKeywords),
      PfaCategory.loneliness: _matchCount(lower, _lonelinessKeywords),
      PfaCategory.painTrapped: _matchCount(lower, _painTrappedKeywords),
      PfaCategory.uncertainty: _matchCount(lower, _uncertaintyKeywords),
    };

    PfaCategory winner = PfaCategory.firstContact;
    var maxScore = 0;
    for (final entry in categoryScores.entries) {
      if (entry.value > maxScore) {
        winner = entry.key;
        maxScore = entry.value;
      }
    }

    if (maxScore > 0) return winner;
    if (riskScore >= 80) return PfaCategory.panicBreathing;
    if (riskScore >= 50) return PfaCategory.uncertainty;
    return PfaCategory.firstContact;
  }

  bool _containsAny(String text, List<String> keywords) =>
      keywords.any((kw) => text.contains(kw));

  int _matchCount(String text, List<String> keywords) =>
      keywords.where((kw) => text.contains(kw)).length;

  /// Selects a random PFA message for the given category.
  /// Prioritizes vulnerability-priority messages if isVulnerable=true.
  PfaMessage? selectMessage(
    PfaCategory category, {
    bool isVulnerable = false,
    int riskScore = 0,
    String seed = '',
  }) {
    final candidates = PfaMessages.forCategory(category);
    if (candidates.isEmpty) return null;

    var filtered = candidates;
    if (isVulnerable) {
      final vulnerableOnly =
          filtered.where((m) => m.vulnerabilityPriority > 0).toList();
      if (vulnerableOnly.isNotEmpty) filtered = vulnerableOnly;
    }

    if (riskScore >= 80) {
      final calmingOrSafety = filtered
          .where(
            (m) => m.pfaComponent == 'Calming' ||
                m.pfaComponent == 'Safety and Comfort',
          )
          .toList();
      if (calmingOrSafety.isNotEmpty) filtered = calmingOrSafety;
    }

    final base = seed.isEmpty ? category.name : seed;
    final idx = (base.hashCode.abs() + riskScore) % filtered.length;
    return filtered[idx];
  }

  /// Returns the first-contact message (used on initial disaster mode entry).
  PfaMessage firstContactMessage() =>
      selectMessage(PfaCategory.firstContact, seed: 'first-contact') ??
      PfaMessages.forCategory(PfaCategory.firstContact).first;

  /// Starts a timer that fires [onTimeout] if user hasn't responded in [duration].
  void startNoResponseTimer({
    required VoidCallback onTimeout,
    Duration duration = const Duration(minutes: 10),
  }) {
    _noResponseTimer?.cancel();
    _noResponseTimer = Timer(duration, onTimeout);
  }

  void cancelNoResponseTimer() {
    _noResponseTimer?.cancel();
    _noResponseTimer = null;
  }

  void resetNoResponseTimer({
    required VoidCallback onTimeout,
    Duration duration = const Duration(minutes: 10),
  }) {
    startNoResponseTimer(onTimeout: onTimeout, duration: duration);
  }
}
