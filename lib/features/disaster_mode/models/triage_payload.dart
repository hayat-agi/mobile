import 'dart:typed_data';
import 'disaster_enums.dart';

/// Compact 8-byte bitmask payload for disaster triage status.
///
/// Wire format:
/// ```
/// Byte 0: Header
///   [7:6]  Protocol version (0b01 = v1)
///   [5:4]  Status type (00=injured, 01=trapped, 10=safe)
///   [3:0]  Severity nibble (0–15, derived from triage score)
///
/// Byte 1: Injury flags
///   [7] Bleeding  [6] Fracture  [5] Breathing  [4] Head
///   [3] Burn      [2] Crush     [1:0] Reserved
///
/// Byte 2: Situation flags
///   [7] Under rubble  [6] No exit   [5] Gas leak  [4] Fire
///   [3] Flooding      [2] Structural risk  [1:0] Reserved
///
/// Byte 3: Needs flags
///   [7] Water   [6] Food     [5] Medical  [4] Warmth
///   [3] Light   [2] Communication  [1:0] Reserved
///
/// Byte 4: People flags
///   [7] Alone   [6] Children  [5] Elderly  [4] Disabled
///   [3] Pregnant  [2] Multiple injured  [1:0] Reserved
///
/// Byte 5: People count
///   [7:4]  Adults  (0–15)
///   [3:0]  Children (0–15)
///
/// Byte 6: Triage score (0–255)
///
/// Byte 7: Checksum (XOR of bytes 0–6)
/// ```
class TriagePayload {
  static const int payloadLength = 8;
  static const int _protocolVersion = 0x01; // v1

  final DisasterStatus status;
  final Set<InjuryChip> injuries;
  final Set<SituationChip> situations;
  final Set<NeedChip> needs;
  final Set<PeopleChip> people;
  final int adultCount;
  final int childCount;
  final int triageScore;

  const TriagePayload({
    required this.status,
    this.injuries = const {},
    this.situations = const {},
    this.needs = const {},
    this.people = const {},
    this.adultCount = 1,
    this.childCount = 0,
    required this.triageScore,
  });

  /// Encode to 8-byte bitmask payload.
  Uint8List encode() {
    final bytes = Uint8List(payloadLength);

    // Byte 0: Header — version(2) | status(2) | severity(4)
    final severity = (triageScore * 15 / 255).round().clamp(0, 15);
    bytes[0] = ((_protocolVersion & 0x03) << 6) |
        ((status.bitmaskValue & 0x03) << 4) |
        (severity & 0x0F);

    // Byte 1: Injury flags
    bytes[1] = _encodeFlags<InjuryChip>(injuries, InjuryChip.values);

    // Byte 2: Situation flags
    bytes[2] = _encodeFlags<SituationChip>(situations, SituationChip.values);

    // Byte 3: Needs flags
    bytes[3] = _encodeFlags<NeedChip>(needs, NeedChip.values);

    // Byte 4: People flags
    bytes[4] = _encodeFlags<PeopleChip>(people, PeopleChip.values);

    // Byte 5: People count — adults(4) | children(4)
    bytes[5] = ((adultCount.clamp(0, 15) & 0x0F) << 4) |
        (childCount.clamp(0, 15) & 0x0F);

    // Byte 6: Triage score
    bytes[6] = triageScore.clamp(0, 255);

    // Byte 7: Checksum (XOR of bytes 0–6)
    int checksum = 0;
    for (int i = 0; i < 7; i++) {
      checksum ^= bytes[i];
    }
    bytes[7] = checksum;

    return bytes;
  }

  /// Decode an 8-byte payload back into a [TriagePayload].
  /// Returns `null` if checksum fails or length is wrong.
  static TriagePayload? decode(Uint8List bytes) {
    if (bytes.length != payloadLength) return null;

    // Verify checksum
    int checksum = 0;
    for (int i = 0; i < 7; i++) {
      checksum ^= bytes[i];
    }
    if (checksum != bytes[7]) return null;

    // Byte 0
    final statusBits = (bytes[0] >> 4) & 0x03;
    final status = DisasterStatus.values.firstWhere(
      (s) => s.bitmaskValue == statusBits,
      orElse: () => DisasterStatus.safe,
    );

    // Bytes 1–4: flags
    final injuries = _decodeFlags<InjuryChip>(bytes[1], InjuryChip.values);
    final situations =
        _decodeFlags<SituationChip>(bytes[2], SituationChip.values);
    final needs = _decodeFlags<NeedChip>(bytes[3], NeedChip.values);
    final people = _decodeFlags<PeopleChip>(bytes[4], PeopleChip.values);

    // Byte 5
    final adultCount = (bytes[5] >> 4) & 0x0F;
    final childCount = bytes[5] & 0x0F;

    // Byte 6
    final triageScore = bytes[6];

    return TriagePayload(
      status: status,
      injuries: injuries,
      situations: situations,
      needs: needs,
      people: people,
      adultCount: adultCount,
      childCount: childCount,
      triageScore: triageScore,
    );
  }

  /// Human-readable hex dump for debugging.
  String toHexString(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  // ── Generic flag helpers ────────────────────────────────────────────

  static int _encodeFlags<T>(Set<T> selected, List<T> allValues) {
    int byte = 0;
    for (final chip in selected) {
      final pos = _bitPosition(chip);
      if (pos >= 0) byte |= (1 << pos);
    }
    return byte;
  }

  static Set<T> _decodeFlags<T>(int byte, List<T> allValues) {
    final result = <T>{};
    for (final chip in allValues) {
      final pos = _bitPosition(chip);
      if (pos >= 0 && (byte & (1 << pos)) != 0) {
        result.add(chip);
      }
    }
    return result;
  }

  static int _bitPosition(dynamic chip) {
    if (chip is InjuryChip) return chip.bitPosition;
    if (chip is SituationChip) return chip.bitPosition;
    if (chip is NeedChip) return chip.bitPosition;
    if (chip is PeopleChip) return chip.bitPosition;
    return -1;
  }
}

/// Calculate the triage score from selected chips and status.
int calculateTriageScore({
  required DisasterStatus status,
  required Set<InjuryChip> injuries,
  required Set<SituationChip> situations,
  required Set<PeopleChip> people,
}) {
  int score = status.baseScore;

  for (final chip in injuries) {
    score += chip.scoreModifier;
  }
  for (final chip in situations) {
    score += chip.scoreModifier;
  }
  for (final chip in people) {
    score += chip.scoreModifier;
  }

  return score.clamp(0, 255);
}
