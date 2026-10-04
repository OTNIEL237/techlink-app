DO $$ 
BEGIN 
  -- We assume 'bio' might already exist since onboarding_screen uses it, but just in case:
  IF NOT EXISTS(SELECT * FROM information_schema.columns WHERE table_name='technicians' AND column_name='bio') THEN
    ALTER TABLE technicians ADD COLUMN bio TEXT;
  END IF;
  
  -- Add 'availability' as JSONB
  IF NOT EXISTS(SELECT * FROM information_schema.columns WHERE table_name='technicians' AND column_name='availability') THEN
    ALTER TABLE technicians ADD COLUMN availability JSONB DEFAULT '{}';
  END IF;
END $$;
