-- =============================================================================
-- FICHIER : 022_add_performance_indexes.sql
-- RÔLE : Optimisation des performances et réduction de latence globale :
--         - Index sur missions (client_id, technician_id, status, created_at DESC)
--         - Index sur messages (mission_id, sender_id, created_at DESC)
--         - Index sur quotes (mission_id)
--         - Index sur ratings (mission_id, client_id, technician_id)
--         - Index sur users (role) et technicians (validation_status).
-- MODULE : Schéma de base de données / Optimisation & Indexation
-- DÉPENDANCES : public.missions, public.messages, public.quotes, public.ratings, public.users, public.technicians
-- SÉCURITÉ / RLS : Sans impact RLS (optimisation du planificateur d'exécution PostgreSQL).
-- =============================================================================

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
