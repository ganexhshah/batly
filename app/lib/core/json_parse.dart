/// Laravel collections keyed by ID often JSON-encode as objects, not arrays.
List<dynamic> parseApiList(dynamic value) {
  if (value == null) return const [];
  if (value is List) return value;
  if (value is Map) return value.values.toList();
  return const [];
}

/// Participant rows from tournament APIs; ignores scalar/object garbage.
List<Map<String, dynamic>> parseParticipantList(dynamic value) {
  final raw = parseApiList(value);
  return raw
      .whereType<Map>()
      .map((p) => Map<String, dynamic>.from(p))
      .toList();
}

Map<String, dynamic> parseApiMap(dynamic value) {
  if (value == null) return {};
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}
