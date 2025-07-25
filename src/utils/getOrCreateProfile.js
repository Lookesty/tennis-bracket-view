import { supabase } from '../supabaseClient';

export async function getOrCreateProfile({ firstName, lastName, email, phone, dateOfBirth, gender }) {
  // 1. Try to find an existing profile
  let { data: existing, error } = await supabase
    .from('profiles')
    .select('id')
    .eq('email', email)
    .single();

  if (existing) return existing.id;

  // 2. If not found, insert a new profile
  let { data: inserted, error: insertError } = await supabase
    .from('profiles')
    .insert([{ first_name: firstName, last_name: lastName, email, phone, date_of_birth: dateOfBirth, gender }])
    .select('id')
    .single();

  if (inserted) return inserted.id;
  throw new Error('Could not create profile');
} 