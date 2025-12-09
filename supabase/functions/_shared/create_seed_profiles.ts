import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// IMPORTANT: Replace with your actual Supabase project reference
const SUPABASE_PROJECT_REF = 'rrbsjmfwahaerkfhpegv'; 

// Get Supabase credentials from environment variables
const supabaseUrl = Deno.env.get('SUPABASE_URL');
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables are required.');
  Deno.exit(1);
}

const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

// --- Seed Data ---
const firstNames = [
  'Alex', 'Ben', 'Chris', 'David', 'Ethan',
  'Fiona', 'Grace', 'Hannah', 'Isla', 'Jessica'
];

const ages = [24, 28, 22, 29, 25, 23, 27, 26, 28, 24];

const bios = [
  'Just seeing what happens.',
  'Lover of good coffee, long walks, and witty banter.',
  'Probably thinking about what to eat next.',
  'Trying to find someone who can keep up with my adventurous spirit.',
  'Fluent in sarcasm and movie quotes.',
  'If you can make me laugh, you\'ve already won.',
  'Looking for my travel buddy. Where are we going next?',
  'Dog lover, foodie, and aspiring globetrotter.',
  'Tell me your favorite song and I\'ll tell you mine.',
  'Not great at writing these things. Let\'s just chat.'
];

const GENDER_OPTIONS = ['Male', 'Female', 'Non-Binary'];

async function createSeedProfiles() {
  console.log('Starting to create 10 seed profiles...');

  for (let i = 0; i < 10; i++) {
    const personIndex = i + 1;
    console.log(`Creating profile for person ${personIndex}...`);

    // Construct the photo URLs
    const photoUrls = [];
    for (let j = 1; j <= 3; j++) {
      const photoUrl = `https://${SUPABASE_PROJECT_REF}.supabase.co/storage/v1/object/public/seed-photos/person_${personIndex}_${j}.jpg`;
      photoUrls.push(photoUrl);
    }

    // Prepare profile data
    const profileData = {
      first_name: firstNames[i],
      age: ages[i],
      bio: bios[i],
      photos: photoUrls,
      job_title: 'Professional Fun-Haver',
      company: 'Life Inc.',
      school: 'School of Hard Knocks',
      gender: i < 5 ? GENDER_OPTIONS[0] : GENDER_OPTIONS[1], // 5 males, 5 females
      show_gender: true,
      show_orientation: true,
      is_seed_profile: true, // This is the crucial flag
      // Add default values for any other non-nullable fields
      like_count: 15,
      super_like_count: 3,
      last_active: new Date().toISOString(),
      location: 'POINT(0 0)', // Default location, can be updated if needed
    };

    // Insert profile into the database
    const { data, error } = await supabaseAdmin
      .from('profiles')
      .insert([profileData])
      .select();

    if (error) {
      console.error(`Error creating profile for person ${personIndex}:`, error.message);
    } else {
      console.log(`Successfully created profile for ${firstNames[i]} with ID: ${data[0].id}`);
    }
  }

  console.log('--- Seed profile creation complete! ---');
}

// Run the script
createSeedProfiles();
