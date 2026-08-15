import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

const _supabaseUrl = 'https://azttitaynheqvoohlipr.supabase.co';
const _supabaseAnonKey = 'sb_publishable_yIrRAyYnpvsDiG0UTzAReQ_elMw1D18';