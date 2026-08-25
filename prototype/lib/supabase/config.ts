const supabaseUrlEnvName = "NEXT_PUBLIC_SUPABASE_URL";
const publishableKeyEnvName = "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY";

export class SupabaseConfigError extends Error {
  constructor() {
    super(
      `Supabase is not configured. Set ${supabaseUrlEnvName} and ${publishableKeyEnvName}.`,
    );
    this.name = "SupabaseConfigError";
  }
}

export function getSupabaseConfig() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL?.trim();
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY?.trim();

  if (!url || !publishableKey) {
    throw new SupabaseConfigError();
  }

  let parsedUrl: URL;
  try {
    parsedUrl = new URL(url);
  } catch {
    throw new SupabaseConfigError();
  }

  const isLocalHttp =
    parsedUrl.protocol === "http:" &&
    (parsedUrl.hostname === "localhost" ||
      parsedUrl.hostname === "127.0.0.1");

  if (parsedUrl.protocol !== "https:" && !isLocalHttp) {
    throw new SupabaseConfigError();
  }

  return {
    url: parsedUrl.toString().replace(/\/$/, ""),
    publishableKey,
  };
}
