-- Clears every verified badge earned before verify-face, so everyone
-- re-verifies once. Until 20261009000000_server_face_verification.sql the app
-- wrote is_verified itself, so those badges can't be told apart from forged
-- ones. Attempts made through verify-face are kept.
--
-- Not a migration yet, on purpose: verify-face is switched off in the app
-- (faceVerificationEnabled in lib/globals.dart) and verify-face has no AWS key
-- (Rekognition, held until the app earns money, decided 2026-10-10), so
-- clearing now would leave nobody able to earn the badge back.
-- OK'd 2026-10-09: move this into migrations/ (with a timestamp) in the same
-- release that turns verification on, once the key is set and
-- face_compare_monthly_cap is raised above 0.
update public.profiles p
set is_verified = false
where is_verified
  and not exists (
    select 1 from public.face_verification_attempts a
    where a.user_id = p.id and a.verified
  );
