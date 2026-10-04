-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.spatial_ref_sys (
  srid integer NOT NULL CHECK (srid > 0 AND srid <= 998999),
  auth_name character varying,
  auth_srid integer,
  srtext character varying,
  proj4text character varying,
  CONSTRAINT spatial_ref_sys_pkey PRIMARY KEY (srid)
);
CREATE TABLE public.users (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  phone character varying NOT NULL UNIQUE,
  name character varying,
  photo_url text,
  role character varying NOT NULL CHECK (role::text = ANY (ARRAY['client'::character varying, 'technician'::character varying, 'admin'::character varying]::text[])),
  is_active boolean DEFAULT true,
  fcm_token text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  avatar_url text,
  language character varying DEFAULT 'fr'::character varying,
  dark_mode boolean DEFAULT false,
  is_banned boolean DEFAULT false,
  CONSTRAINT users_pkey PRIMARY KEY (id)
);
CREATE TABLE public.technicians (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL UNIQUE,
  bio text,
  experience_years integer DEFAULT 0,
  specialties ARRAY NOT NULL DEFAULT '{}'::text[],
  zone_radius_km integer DEFAULT 10,
  current_lat double precision,
  current_lng double precision,
  last_location_update timestamp with time zone,
  status character varying DEFAULT 'available'::character varying CHECK (status::text = ANY (ARRAY['available'::character varying, 'busy'::character varying, 'offline'::character varying]::text[])),
  is_verified boolean DEFAULT false,
  validation_status character varying DEFAULT 'pending'::character varying CHECK (validation_status::text = ANY (ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying]::text[])),
  rejection_reason text,
  mtn_number character varying,
  orange_number character varying,
  total_missions integer DEFAULT 0,
  rating_average numeric DEFAULT 0.00,
  rating_count integer DEFAULT 0,
  total_earnings numeric DEFAULT 0.00,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  wallet_balance numeric DEFAULT 0,
  subscription_type text DEFAULT 'none'::text CHECK (subscription_type = ANY (ARRAY['none'::text, 'monthly'::text, 'yearly'::text, 'trial'::text])),
  subscription_status text DEFAULT 'inactive'::text CHECK (subscription_status = ANY (ARRAY['active'::text, 'inactive'::text, 'expired'::text, 'cancelled'::text])),
  subscription_start_date timestamp without time zone,
  subscription_end_date timestamp without time zone,
  trial_start_date timestamp without time zone,
  trial_end_date timestamp without time zone,
  subscription_price_paid numeric,
  subscription_payment_reference text,
  photo_url text,
  availability jsonb DEFAULT '{}'::jsonb,
  hourly_rate integer DEFAULT 0,
  CONSTRAINT technicians_pkey PRIMARY KEY (id),
  CONSTRAINT technicians_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.technician_documents (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  technician_id uuid NOT NULL,
  document_type character varying NOT NULL,
  file_url text NOT NULL,
  file_name character varying,
  is_verified boolean DEFAULT false,
  verified_by uuid,
  verified_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT technician_documents_pkey PRIMARY KEY (id),
  CONSTRAINT technician_documents_technician_id_fkey FOREIGN KEY (technician_id) REFERENCES public.technicians(id),
  CONSTRAINT technician_documents_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES public.users(id)
);
CREATE TABLE public.categories (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  name character varying NOT NULL UNIQUE,
  slug character varying NOT NULL UNIQUE,
  icon_url text,
  description text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  icon_name text DEFAULT 'build'::text,
  CONSTRAINT categories_pkey PRIMARY KEY (id)
);
CREATE TABLE public.missions (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  client_id uuid NOT NULL,
  technician_id uuid,
  category_id uuid,
  problem_description text NOT NULL,
  problem_photos ARRAY DEFAULT '{}'::text[],
  urgency_level character varying DEFAULT 'normal'::character varying CHECK (urgency_level::text = ANY (ARRAY['low'::character varying, 'normal'::character varying, 'urgent'::character varying]::text[])),
  ai_solution text,
  ai_category_detected character varying,
  client_address text,
  client_lat double precision,
  client_lng double precision,
  status character varying DEFAULT 'pending'::character varying CHECK (status::text = ANY (ARRAY['searching'::character varying, 'pending'::character varying, 'accepted'::character varying, 'technician_enroute'::character varying, 'in_progress'::character varying, 'quote_sent'::character varying, 'quote_accepted'::character varying, 'payment_pending'::character varying, 'paid'::character varying, 'completed'::character varying, 'cancelled'::character varying, 'in_dispute'::character varying, 'cancelled_refunded'::character varying]::text[])),
  requested_at timestamp with time zone DEFAULT now(),
  accepted_at timestamp with time zone,
  started_at timestamp with time zone,
  completed_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  paid_at timestamp with time zone,
  CONSTRAINT missions_pkey PRIMARY KEY (id),
  CONSTRAINT missions_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.users(id),
  CONSTRAINT missions_technician_id_fkey FOREIGN KEY (technician_id) REFERENCES public.users(id),
  CONSTRAINT missions_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id)
);
CREATE TABLE public.mission_requests (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  mission_id uuid NOT NULL,
  technician_id uuid NOT NULL,
  status character varying DEFAULT 'pending'::character varying CHECK (status::text = ANY (ARRAY['pending'::character varying, 'accepted'::character varying, 'refused'::character varying, 'timeout'::character varying]::text[])),
  sent_at timestamp with time zone DEFAULT now(),
  responded_at timestamp with time zone,
  timeout_at timestamp with time zone DEFAULT (now() + '00:02:00'::interval),
  CONSTRAINT mission_requests_pkey PRIMARY KEY (id),
  CONSTRAINT mission_requests_mission_id_fkey FOREIGN KEY (mission_id) REFERENCES public.missions(id),
  CONSTRAINT mission_requests_technician_id_fkey FOREIGN KEY (technician_id) REFERENCES public.technicians(id)
);
CREATE TABLE public.quotes (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  mission_id uuid NOT NULL,
  technician_id uuid NOT NULL,
  lines jsonb NOT NULL DEFAULT '[]'::jsonb,
  subtotal numeric NOT NULL DEFAULT 0,
  commission_rate numeric DEFAULT 5.00,
  commission_amount numeric NOT NULL DEFAULT 0,
  net_technician numeric NOT NULL DEFAULT 0,
  onsite_photos ARRAY DEFAULT '{}'::text[],
  status character varying DEFAULT 'pending'::character varying CHECK (status::text = ANY (ARRAY['pending'::character varying, 'accepted'::character varying, 'refused'::character varying]::text[])),
  pdf_url text,
  sent_at timestamp with time zone DEFAULT now(),
  responded_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT quotes_pkey PRIMARY KEY (id),
  CONSTRAINT quotes_mission_id_fkey FOREIGN KEY (mission_id) REFERENCES public.missions(id),
  CONSTRAINT quotes_technician_id_fkey FOREIGN KEY (technician_id) REFERENCES public.users(id)
);
CREATE TABLE public.payments (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  mission_id uuid,
  quote_id uuid,
  client_id uuid,
  technician_id uuid,
  amount numeric,
  commission_amount numeric,
  technician_amount numeric,
  payment_method character varying CHECK (payment_method::text = ANY (ARRAY['mtn_money'::character varying, 'orange_money'::character varying]::text[])),
  payer_phone character varying,
  provider_transaction_id character varying,
  provider_reference character varying,
  status character varying DEFAULT 'pending'::character varying CHECK (status::text = ANY (ARRAY['pending'::character varying, 'processing'::character varying, 'success'::character varying, 'failed'::character varying, 'refunded'::character varying]::text[])),
  payout_status character varying DEFAULT 'pending'::character varying CHECK (payout_status::text = ANY (ARRAY['pending'::character varying, 'paid'::character varying, 'failed'::character varying]::text[])),
  payout_at timestamp with time zone,
  payout_reference character varying,
  initiated_at timestamp with time zone DEFAULT now(),
  confirmed_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  method text DEFAULT 'mobile_money'::text,
  notchpay_reference text,
  paid_at timestamp with time zone,
  platform_fee numeric DEFAULT 0,
  commission_percentage numeric DEFAULT 0,
  is_mission_payment boolean DEFAULT true,
  camerpay_reference text,
  camerpay_transaction_id text,
  CONSTRAINT payments_pkey PRIMARY KEY (id),
  CONSTRAINT payments_mission_id_fkey FOREIGN KEY (mission_id) REFERENCES public.missions(id),
  CONSTRAINT payments_quote_id_fkey FOREIGN KEY (quote_id) REFERENCES public.quotes(id),
  CONSTRAINT payments_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.users(id),
  CONSTRAINT payments_technician_id_fkey FOREIGN KEY (technician_id) REFERENCES public.users(id)
);
CREATE TABLE public.ratings (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  mission_id uuid NOT NULL UNIQUE,
  client_id uuid NOT NULL,
  technician_id uuid NOT NULL,
  score integer NOT NULL CHECK (score >= 1 AND score <= 5),
  comment text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT ratings_pkey PRIMARY KEY (id),
  CONSTRAINT ratings_mission_id_fkey FOREIGN KEY (mission_id) REFERENCES public.missions(id),
  CONSTRAINT ratings_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.users(id),
  CONSTRAINT ratings_technician_id_fkey FOREIGN KEY (technician_id) REFERENCES public.users(id)
);
CREATE TABLE public.messages (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  mission_id uuid NOT NULL,
  sender_id uuid NOT NULL,
  content text NOT NULL,
  message_type character varying DEFAULT 'text'::character varying CHECK (message_type::text = ANY (ARRAY['text'::character varying, 'image'::character varying, 'system'::character varying]::text[])),
  image_url text,
  is_read boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  sender_role text DEFAULT 'client'::text,
  CONSTRAINT messages_pkey PRIMARY KEY (id),
  CONSTRAINT messages_mission_id_fkey FOREIGN KEY (mission_id) REFERENCES public.missions(id),
  CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id)
);
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL,
  title character varying NOT NULL,
  body text NOT NULL,
  type character varying CHECK (type::text = ANY (ARRAY['system'::character varying, 'mission'::character varying, 'message'::character varying, 'promo'::character varying, 'broadcast'::character varying, 'payment'::character varying]::text[])),
  data jsonb DEFAULT '{}'::jsonb,
  is_read boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.admin_logs (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  admin_id uuid NOT NULL,
  action character varying NOT NULL,
  target_type character varying,
  target_id uuid,
  details jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT admin_logs_pkey PRIMARY KEY (id),
  CONSTRAINT admin_logs_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.users(id)
);
CREATE TABLE public.wallet_transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  technician_id uuid,
  mission_id uuid,
  type text NOT NULL,
  amount numeric NOT NULL,
  balance_after numeric DEFAULT 0,
  description text,
  reference text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT wallet_transactions_pkey PRIMARY KEY (id),
  CONSTRAINT wallet_transactions_technician_id_fkey FOREIGN KEY (technician_id) REFERENCES public.users(id),
  CONSTRAINT wallet_transactions_mission_id_fkey FOREIGN KEY (mission_id) REFERENCES public.missions(id)
);
CREATE TABLE public.technician_subscriptions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  technician_id uuid NOT NULL,
  subscription_type text NOT NULL CHECK (subscription_type = ANY (ARRAY['monthly'::text, 'yearly'::text, 'trial'::text])),
  amount_paid numeric,
  period_start timestamp without time zone NOT NULL DEFAULT now(),
  period_end timestamp without time zone NOT NULL,
  trial_type text CHECK (trial_type IS NULL OR trial_type = 'free_trial'::text),
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'active'::text, 'expired'::text, 'cancelled'::text, 'failed'::text])),
  payment_reference text,
  camerpay_transaction_id text,
  created_at timestamp without time zone NOT NULL DEFAULT now(),
  updated_at timestamp without time zone NOT NULL DEFAULT now(),
  cancelled_at timestamp without time zone,
  CONSTRAINT technician_subscriptions_pkey PRIMARY KEY (id),
  CONSTRAINT technician_subscriptions_technician_id_fkey FOREIGN KEY (technician_id) REFERENCES public.technicians(id)
);
CREATE TABLE public.calls (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  caller_id uuid NOT NULL,
  receiver_id uuid NOT NULL,
  call_id text NOT NULL,
  status text NOT NULL DEFAULT 'ringing'::text CHECK (status = ANY (ARRAY['ringing'::text, 'accepted'::text, 'declined'::text, 'ended'::text, 'missed'::text])),
  CONSTRAINT calls_pkey PRIMARY KEY (id),
  CONSTRAINT calls_caller_id_fkey FOREIGN KEY (caller_id) REFERENCES public.users(id),
  CONSTRAINT calls_receiver_id_fkey FOREIGN KEY (receiver_id) REFERENCES public.users(id)
);
CREATE TABLE public.platform_settings (
  id integer NOT NULL DEFAULT nextval('platform_settings_id_seq'::regclass),
  platform_fee_percentage numeric DEFAULT 15.0,
  subscription_price numeric DEFAULT 10000.0,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  CONSTRAINT platform_settings_pkey PRIMARY KEY (id)
);
CREATE TABLE public.payouts (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  technician_id uuid,
  amount numeric NOT NULL,
  payment_method text NOT NULL,
  phone_number text,
  status text DEFAULT 'pending'::text,
  admin_id uuid,
  processed_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  CONSTRAINT payouts_pkey PRIMARY KEY (id),
  CONSTRAINT payouts_technician_id_fkey FOREIGN KEY (technician_id) REFERENCES public.technicians(id),
  CONSTRAINT payouts_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES auth.users(id)
);
CREATE TABLE public.disputes (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  mission_id uuid,
  reporter_id uuid,
  reason text NOT NULL,
  description text,
  status text DEFAULT 'open'::text,
  resolution_notes text,
  admin_id uuid,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  CONSTRAINT disputes_pkey PRIMARY KEY (id),
  CONSTRAINT disputes_mission_id_fkey FOREIGN KEY (mission_id) REFERENCES public.missions(id),
  CONSTRAINT disputes_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES public.users(id),
  CONSTRAINT disputes_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES auth.users(id)
);
CREATE TABLE public.broadcasts (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  title text NOT NULL,
  message text NOT NULL,
  target_audience text DEFAULT 'all'::text,
  admin_id uuid,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  CONSTRAINT broadcasts_pkey PRIMARY KEY (id),
  CONSTRAINT broadcasts_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES auth.users(id)
);
CREATE TABLE public.admin_messages (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid,
  sender_id uuid,
  sender_role text NOT NULL,
  content text NOT NULL,
  is_read boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  CONSTRAINT admin_messages_pkey PRIMARY KEY (id),
  CONSTRAINT admin_messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT admin_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id)
);