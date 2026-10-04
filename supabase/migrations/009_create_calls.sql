-- Create calls table for ZEGOCLOUD Voice Call integration
CREATE TABLE IF NOT EXISTS calls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  caller_id UUID NOT NULL CONSTRAINT calls_caller_id_fkey REFERENCES users(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL CONSTRAINT calls_receiver_id_fkey REFERENCES users(id) ON DELETE CASCADE,
  call_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('ringing', 'accepted', 'declined', 'ended', 'missed')) DEFAULT 'ringing'
);

-- Enable RLS
ALTER TABLE calls ENABLE ROW LEVEL SECURITY;

-- Policies for calls table
CREATE POLICY "Users can insert calls where they are the caller" ON calls
  FOR INSERT WITH CHECK (auth.uid() = caller_id);

CREATE POLICY "Users can read calls where they are either caller or receiver" ON calls
  FOR SELECT USING (auth.uid() = caller_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can update calls where they are either caller or receiver" ON calls
  FOR UPDATE USING (auth.uid() = caller_id OR auth.uid() = receiver_id);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_calls_caller_id ON calls(caller_id);
CREATE INDEX IF NOT EXISTS idx_calls_receiver_id ON calls(receiver_id);
CREATE INDEX IF NOT EXISTS idx_calls_status ON calls(status);

-- Enable realtime replication for calls table
alter publication supabase_realtime add table calls;
