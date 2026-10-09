-- Clears every verified badge earned before verify-face, so everyone
-- re-verifies once. Until 20261009000000_server_face_verification.sql the app
-- wrote is_verified itself, so those badges can't be told apart from forged
-- ones. Attempts made through verify-face are kept.
--
-- Not a migration yet, on purpose: verify-face is switched off in the app
-- (faceVerificationEnabled in lib/globals.dart) until it has a face-matching
-- service, so clearing now would leave nobody able to earn the badge back.
-- OK'd 2026-10-09: move this into migrations/ (with a timestamp) in the same
-- release that turns verification on.
update public.profiles p
set is_verified = false
where is_verified
  and not exists (
    select 1 from public.face_verification_attempts a
    where a.user_id = p.id and a.verified
  );
