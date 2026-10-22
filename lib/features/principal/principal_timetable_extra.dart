import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_providers.dart';

/// Opening / closing times that differ from the school default on certain
/// days, e.g. {3: (start: null, end: '12:30')} = Wednesday closes at 12:30.
/// A null start or end means "same as the school day".
typedef PnDayHours = Map<int, ({String? start, String? end})>;

String _hm(Object? v) {
  final s = (v ?? '').toString().trim();
  return s.length >= 5 ? s.substring(0, 5) : s;
}

/// Reads school_timetable_settings.day_hours. If that column has not been
/// added yet (see timetable_day_hours.sql) this simply returns "no custom
/// days", so nothing else breaks.
final timetableDayHoursProvider = FutureProvider.family<PnDayHours, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    final row = await client.from('school_timetable_settings').select('day_hours').eq('school_id', schoolId).maybeSingle();
    final raw = row?['day_hours'];
    final out = <int, ({String? start, String? end})>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        final d = int.tryParse('$k');
        if (d == null || d < 1 || d > 7 || v is! Map) return;
        final s = _hm(v['start']);
        final e = _hm(v['end']);
        if (s.isEmpty && e.isEmpty) return;
        out[d] = (start: s.isEmpty ? null : s, end: e.isEmpty ? null : e);
      });
    }
    return out;
  } catch (_) {
    return <int, ({String? start, String? end})>{};
  }
});

/// Saves the per-day hours. The settings row must already exist (the
/// settings page saves it first).
Future<void> saveTimetableDayHours(SupabaseClient client, String schoolId, PnDayHours hours) async {
  await client.from('school_timetable_settings').update({
    'day_hours': {
      for (final e in hours.entries)
        '${e.key}': {
          if (e.value.start != null) 'start': e.value.start,
          if (e.value.end != null) 'end': e.value.end,
        },
    },
  }).eq('school_id', schoolId);
}

/// "Put these periods of this subject on that day" (e.g. Geography, 2
/// periods, Saturday). Day numbers: 1 = Monday ... 7 = Sunday.
class PnDayRequest {
  final int day;
  final String subjectId;
  final int periods;
  const PnDayRequest({required this.day, required this.subjectId, required this.periods});

  Map<String, dynamic> toJson() => {'day': day, 'subject_id': subjectId, 'periods': periods};
}

/// Same call as before, plus the two optional requests the function now
/// understands: different hours for this run only, and lessons on an extra day.
Future<Map<String, dynamic>> generateTimetableWithOptions(
  SupabaseClient client, {
  required String schoolId,
  required String scopeType, // 'class' | 'department' | 'school'
  String? departmentId,
  String? classId,
  String? principalNote,
  String? hoursStart, // 'HH:mm'
  String? hoursEnd, // 'HH:mm'
  List<PnDayRequest> dayRequests = const [],
}) async {
  try {
    final response = await client.functions.invoke('generate-timetable', body: {
      'school_id': schoolId,
      'scope_type': scopeType,
      if (departmentId != null) 'department_id': departmentId,
      if (classId != null) 'class_id': classId,
      if (principalNote != null && principalNote.trim().isNotEmpty) 'principal_note': principalNote.trim(),
      if (hoursStart != null || hoursEnd != null)
        'hours_override': {
          if (hoursStart != null) 'start': hoursStart,
          if (hoursEnd != null) 'end': hoursEnd,
        },
      if (dayRequests.isNotEmpty) 'day_requests': [for (final r in dayRequests) r.toJson()],
    });
    final data = response.data;
    if (data is! Map) throw Exception('Timetable generation failed.');
    if (data['success'] != true) throw Exception(data['message'] ?? 'Timetable generation failed.');
    return Map<String, dynamic>.from(data);
  } on FunctionException catch (e) {
    final d = e.details;
    final msg = d is Map ? d['message'] : null;
    throw Exception(msg ?? 'Timetable generation failed (${e.status}).');
  }
}
