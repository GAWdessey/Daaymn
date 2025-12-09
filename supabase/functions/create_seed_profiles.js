require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

// --- CONFIGURATION ---
// IMPORTANT: Replace with your actual Supabase project reference if it differs.
const SUPABASE_PROJECT_REF = 'rrbsjmfwahaerkfhpegv';

// --- SCRIPT START ---

// 1. Initialize Supabase Admin Client
// This uses the SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY from your .env file.
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey || supabaseUrl.includes('YOUR_SUPABASE_URL')) {
  console.error('FATAL: Your Supabase credentials are not set correctly in the .env file.');
  process.exit(1);
}

const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

// --- DATA FOR SEED PROFILES ---
const names = [
  'Alex', 'Ben', 'Chris', 'David', 'Ethan',
  'Fiona', 'Grace', 'Hannah', 'Isla', 'Jessica'
];
const ages = [24, 28, 22, 29, 25, 23, 27, 26, 28, 24];
const GENDER_OPTIONS = ['Male', 'Female'];

// --- CORE LOGIC ---

async function createSeedProfiles() {
  console.log('--- Starting Seed Profile Creation ---');
  console.log('This script will create users in `auth.users` and then add corresponding rows to `public.profiles`.');

  for (let i = 0; i < 10; i++) {
    const personIndex = i + 1;
    const name = names[i];
    console.log(`\nProcessing Person ${personIndex}/${names.length}: ${name}`);

    // --- STEP 1: Create the user in `auth.users` ---
    // We must do this first to get a valid user ID, which is required by the `profiles.id` foreign key.
    const email = `seed_user_${personIndex}@yourapp.com`; // Unique email for the new user
    const password = `password-${Math.random().toString(36).substring(2)}`; // Secure, random password

    console.log(`  -> Step 1: Creating auth user with email: ${email}...`);
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: email,
      password: password,
      email_confirm: true, // Mark email as confirmed to make the user active
    });

    if (authError) {
      console.error(`  [!] FAILED (Auth): Could not create user for ${name}. Error: ${authError.message}`);
      continue; // Skip to the next person if we can't create an auth user
    }

    const newUserId = authData.user.id;
    console.log(`     Success! User created with ID: ${newUserId}`);

    // --- STEP 2: Create the corresponding profile in `public.profiles` ---
    console.log(`  -> Step 2: Creating public profile for user ID: ${newUserId}...`);
    const imageUrls = [];
    for (let j = 1; j <= 3; j++) {
      const photoUrl = `https://${SUPABASE_PROJECT_REF}.supabase.co/storage/v1/object/public/seed-photos/person_${personIndex}_${j}.jpg`;
      imageUrls.push(photoUrl);
    }

    const profileData = {
      id: newUserId, // THIS IS THE CRITICAL FIX: Use the ID from the newly created auth user.
      name: name,
      age: ages[i],
      image_urls: imageUrls,
      work: { job_title: 'Professional Fun-Haver', company: 'Life Inc.' },
      gender: i < 5 ? GENDER_OPTIONS[0] : GENDER_OPTIONS[1],
      is_seed_profile: true,
      like_count: 15,
      bio_topics: {},
      last_seen: new Date().toISOString(),
      location: 'POINT(0 0)',
      is_verified: true, // Let's make seed profiles look verified
    };

    const { error: profileError } = await supabaseAdmin
      .from('profiles')
      .insert([profileData]);

    if (profileError) {
      console.error(`  [!] FAILED (Profile): Could not create profile for ${name}. Error: ${profileError.message}`);
    } else {
      console.log(`     Success! Public profile for ${name} created.`);
    }
  }

  console.log('\n--- Seed profile creation complete! ---');
}

// Run the script
createSeedProfiles();
