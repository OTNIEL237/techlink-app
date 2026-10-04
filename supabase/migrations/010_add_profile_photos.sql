-- Add avatar_url to public.users if it doesn't exist
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Add photo_url to public.technicians if it doesn't exist (assuming they might have a separate one, or they just use the user's avatar)
-- Let's add it to technicians as well just in case, but usually it's tied to the user table.
ALTER TABLE IF EXISTS public.technicians ADD COLUMN IF NOT EXISTS photo_url TEXT;
