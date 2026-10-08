// The site's link to the menu database (Supabase). See bachend/README.md.
// The URL and the publishable key are public by design: the row level security in
// bachend/supabase/setup.sql is what protects the data. Never put a service_role or secret key here.
window.SPILVER_DB = {
  url: 'https://vlijgnkdawrkaihjvywd.supabase.co',
  anonKey: 'sb_publishable_S-PUgSzriUfweo6WVBaOhA_baUElrlQ'
};
