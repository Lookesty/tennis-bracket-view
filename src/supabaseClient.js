import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://yuxodqlmvipxzvuyhwgl.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl1eG9kcWxtdmlweHp2dXlod2dsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgxNDQyMTgsImV4cCI6MjA2MzcyMDIxOH0.KRQw4J6fE0D0ScfZkaAyO0BghMf7r4kP-4nHzM1J5hg';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Public client for unauthenticated access
export const publicSupabase = createClient(supabaseUrl, supabaseAnonKey);

export default supabase;
