-- Add call_type to calls table
ALTER TABLE calls 
ADD COLUMN call_type TEXT DEFAULT 'audio' CHECK (call_type IN ('audio', 'video'));
