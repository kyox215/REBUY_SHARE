import type { CookieMethodsServer, CookieOptions } from "@supabase/ssr";

export type ServerCookieStore = {
  getAll: () => Array<{ name: string; value: string }>;
  set: (name: string, value: string, options: CookieOptions) => void;
};

export type ServerCookieMode = "readonly" | "strict";

export function createServerCookieMethods(
  cookieStore: ServerCookieStore,
  mode: ServerCookieMode,
): Pick<CookieMethodsServer, "getAll" | "setAll"> {
  return {
    getAll() {
      return cookieStore.getAll();
    },
    setAll(cookiesToSet) {
      try {
        cookiesToSet.forEach(({ name, value, options }) => {
          cookieStore.set(name, value, options);
        });
      } catch (error) {
        if (mode === "strict") {
          throw error;
        }
      }
    },
  };
}
