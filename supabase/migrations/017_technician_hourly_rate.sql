DO $$ 
BEGIN 
  -- Add 'hourly_rate' to technicians table
  IF NOT EXISTS(SELECT * FROM information_schema.columns WHERE table_name='technicians' AND column_name='hourly_rate') THEN
    ALTER TABLE technicians ADD COLUMN hourly_rate INTEGER DEFAULT 0;
  END IF;
END $$;
