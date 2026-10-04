-- Migration to add performance indexes
-- This reduces latency globally by preventing sequential scans on large tables

-- Missions Table Indexes
CREATE INDEX IF NOT EXISTS idx_missions_client_id ON missions(client_id);
CREATE INDEX IF NOT EXISTS idx_missions_technician_id ON missions(technician_id);
CREATE INDEX IF NOT EXISTS idx_missions_status ON missions(status);
CREATE INDEX IF NOT EXISTS idx_missions_created_at ON missions(created_at DESC);

-- Messages Table Indexes
CREATE INDEX IF NOT EXISTS idx_messages_mission_id ON messages(mission_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);

-- Quotes Table Indexes
CREATE INDEX IF NOT EXISTS idx_quotes_mission_id ON quotes(mission_id);

-- Ratings Table Indexes
CREATE INDEX IF NOT EXISTS idx_ratings_mission_id ON ratings(mission_id);
CREATE INDEX IF NOT EXISTS idx_ratings_client_id ON ratings(client_id);
CREATE INDEX IF NOT EXISTS idx_ratings_technician_id ON ratings(technician_id);

-- Users Table Indexes
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- Technicians Table Indexes
CREATE INDEX IF NOT EXISTS idx_technicians_validation_status ON technicians(validation_status);
