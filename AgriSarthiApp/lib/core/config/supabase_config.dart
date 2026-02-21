import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://djnhdraoijkxsrxgatht.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRqbmhkcmFvaWpreHNyeGdhdGh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAxOTc2MjIsImV4cCI6MjA4NTc3MzYyMn0.bO7-luJxCw7hySoGzonF_Q0njPou7F5bzvgeV6W5cIQ';
  
  // Get the Supabase client instance
  static SupabaseClient get client => Supabase.instance.client;
  
  // Get the current user
  static User? get currentUser => client.auth.currentUser;
  
  // Get the current session
  static Session? get currentSession => client.auth.currentSession;
  
  // Check if user is authenticated
  static bool get isAuthenticated => currentUser != null;
}
