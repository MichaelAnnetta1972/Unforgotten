-- Migration: Add sharing preference columns to account_invitations
-- These columns store the inviter's sharing preference selections at invite time.
-- When the invitation is accepted, these preferences are used to set initial
-- profile_sharing_preferences for the sync connection.

ALTER TABLE account_invitations
ADD COLUMN IF NOT EXISTS sharing_profile_fields BOOLEAN NOT NULL DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS sharing_medical BOOLEAN NOT NULL DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS sharing_gift_idea BOOLEAN NOT NULL DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS sharing_clothing BOOLEAN NOT NULL DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS sharing_hobby BOOLEAN NOT NULL DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS sharing_activity_idea BOOLEAN NOT NULL DEFAULT TRUE;

COMMENT ON COLUMN account_invitations.sharing_profile_fields IS 'Whether to share profile fields (name, address, phone, photo) with invitee';
COMMENT ON COLUMN account_invitations.sharing_medical IS 'Whether to share medical conditions with invitee';
COMMENT ON COLUMN account_invitations.sharing_gift_idea IS 'Whether to share gift ideas with invitee';
COMMENT ON COLUMN account_invitations.sharing_clothing IS 'Whether to share clothing sizes with invitee';
COMMENT ON COLUMN account_invitations.sharing_hobby IS 'Whether to share hobbies with invitee';
COMMENT ON COLUMN account_invitations.sharing_activity_idea IS 'Whether to share activity ideas with invitee';
