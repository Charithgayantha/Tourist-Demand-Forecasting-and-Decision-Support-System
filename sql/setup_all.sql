-- ==========================================
-- 1. CORE DATA TABLES
-- ==========================================

-- national_tourism table
CREATE TABLE IF NOT EXISTS public.national_tourism (
    year INTEGER NOT NULL,
    month INTEGER NOT NULL,
    tourist_arrivals INTEGER,
    india_arrivals INTEGER,
    uk_arrivals INTEGER,
    russia_arrivals INTEGER,
    germany_arrivals INTEGER,
    china_arrivals INTEGER,
    other_arrivals INTEGER,
    visa_applications INTEGER,
    visa_approvals INTEGER,
    covid_impact INTEGER,
    easter_attack_impact INTEGER,
    economic_crisis_impact INTEGER,
    PRIMARY KEY (year, month)
);

-- kandy_weekly_data table
CREATE TABLE IF NOT EXISTS public.kandy_weekly_data (
    week_start DATE NOT NULL PRIMARY KEY,
    week_end DATE,
    year INTEGER,
    month INTEGER,
    week_of_year INTEGER,
    quarter INTEGER,
    festival_intensity_score INTEGER,
    is_esala_perahera INTEGER,
    is_esala_preparation INTEGER,
    is_esala_post_festival INTEGER,
    is_august_buildup INTEGER,
    is_poson_perahera INTEGER,
    is_vesak INTEGER,
    is_sinhala_tamil_new_year INTEGER,
    is_christmas_new_year INTEGER,
    is_deepavali INTEGER,
    is_thai_pongal INTEGER,
    is_monthly_poya_week INTEGER,
    poya_days_away INTEGER,
    is_school_holiday INTEGER,
    is_any_festival INTEGER,
    days_until_next_esala INTEGER,
    avg_weekly_rainfall_mm INTEGER,
    avg_humidity_pct INTEGER,
    is_monsoon_week INTEGER,
    is_covid_period INTEGER,
    is_easter_attack_period INTEGER,
    is_economic_crisis INTEGER,
    is_normal_operation INTEGER,
    estimated_weekly_kandy_arrivals INTEGER,
    festival_demand_multiplier NUMERIC,
    avg_temp_celsius NUMERIC
);

-- kandy_weather_daily table
CREATE TABLE IF NOT EXISTS public.kandy_weather_daily (
    time DATE NOT NULL PRIMARY KEY,
    temperature_2m_max NUMERIC,
    temperature_2m_min NUMERIC,
    temperature_2m_mean NUMERIC,
    apparent_temperature_max NUMERIC,
    apparent_temperature_min NUMERIC,
    apparent_temperature_mean NUMERIC,
    shortwave_radiation_sum NUMERIC,
    precipitation_sum NUMERIC,
    rain_sum NUMERIC,
    snowfall_sum NUMERIC,
    precipitation_hours NUMERIC,
    windspeed_10m_max NUMERIC,
    windgusts_10m_max NUMERIC,
    winddirection_10m_dominant NUMERIC,
    et0_fao_evapotranspiration NUMERIC,
    elevation NUMERIC,
    latitude NUMERIC,
    longitude NUMERIC,
    weathercode INTEGER
);

-- predictions table
CREATE TABLE IF NOT EXISTS public.predictions (
    week_start DATE NOT NULL,
    model_name TEXT NOT NULL,
    week_end DATE,
    is_future BOOLEAN,
    confidence_level NUMERIC,
    predicted_arrivals NUMERIC,
    lower_bound NUMERIC,
    upper_bound NUMERIC,
    features_used JSONB,
    PRIMARY KEY (week_start, model_name)
);


-- ==========================================
-- 2. AUTH & USER PROFILE SCHEMAS
-- ==========================================

-- Create table for User Profiles
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id uuid references auth.users(id) on delete cascade not null primary key,
  email text not null,
  full_name text,
  role text check (role in ('Hotel Manager', 'Tour Operator', 'Government Official', 'Other', 'System Administrator')),
  hotel_name text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Turn on Row Level Security
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Create Policies
DROP POLICY IF EXISTS "Users can view own profile" ON public.user_profiles;
CREATE POLICY "Users can view own profile" ON public.user_profiles
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;
CREATE POLICY "Users can update own profile" ON public.user_profiles
  FOR UPDATE USING (auth.uid() = id);

-- Create an auth trigger (Function) to automatically create a profile when a new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, full_name, role, hotel_name)
  VALUES (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'role',
    new.raw_user_meta_data->>'hotel_name'
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach the trigger to the auth.users table
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();


-- ==========================================
-- 3. ADMIN ROLE OVERRIDE & POLICIES
-- ==========================================

-- Create RLS policy for the System Administrator to manage other profiles
DROP POLICY IF EXISTS "System Administrators can manage all profiles" ON public.user_profiles;
CREATE POLICY "System Administrators can manage all profiles" ON public.user_profiles
  FOR ALL
  USING (
    (SELECT role FROM public.user_profiles WHERE id = auth.uid()) = 'System Administrator'
  )
  WITH CHECK (
    (SELECT role FROM public.user_profiles WHERE id = auth.uid()) = 'System Administrator'
  );

-- Update existing admin user (charithgayantha18@gmail.com) to have the core Admin role
-- (Note: run this AFTER registering your account in the app)
UPDATE public.user_profiles 
SET role = 'System Administrator' 
WHERE email = 'charithgayantha18@gmail.com';
