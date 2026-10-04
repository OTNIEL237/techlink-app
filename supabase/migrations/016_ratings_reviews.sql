-- Create ratings table
CREATE TABLE IF NOT EXISTS public.ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mission_id UUID NOT NULL REFERENCES public.missions(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    technician_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    score INTEGER NOT NULL CHECK (score >= 1 AND score <= 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Unique constraint to prevent multiple ratings for the same mission by the same client
ALTER TABLE public.ratings DROP CONSTRAINT IF EXISTS unique_mission_rating;
ALTER TABLE public.ratings ADD CONSTRAINT unique_mission_rating UNIQUE (mission_id, client_id);

-- Enable RLS
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;

-- Policies
DROP POLICY IF EXISTS "Clients can create ratings for their missions" ON public.ratings;
CREATE POLICY "Clients can create ratings for their missions" ON public.ratings
    FOR INSERT WITH CHECK (auth.uid() = client_id);

DROP POLICY IF EXISTS "Anyone can read ratings" ON public.ratings;

CREATE POLICY "Anyone can read ratings" ON public.ratings
    FOR SELECT USING (true);

-- Function to update technician average rating
CREATE OR REPLACE FUNCTION update_technician_rating()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the rating_average and total_missions
    UPDATE public.technicians
    SET 
        rating_average = (
            SELECT ROUND(AVG(score)::numeric, 1) 
            FROM public.ratings 
            WHERE technician_id = NEW.technician_id
        ),
        total_missions = (
            SELECT COUNT(*) 
            FROM public.ratings 
            WHERE technician_id = NEW.technician_id
        )
    WHERE user_id = NEW.technician_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call the function after a new rating is inserted
DROP TRIGGER IF EXISTS on_rating_inserted ON public.ratings;
CREATE TRIGGER on_rating_inserted
AFTER INSERT OR UPDATE ON public.ratings
FOR EACH ROW EXECUTE FUNCTION update_technician_rating();
