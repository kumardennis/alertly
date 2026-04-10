import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { Database } from "../types/supabaseTypes";

let supabaseClient: SupabaseClient<Database> | undefined;
let supabaseServiceClient: SupabaseClient<Database> | undefined;

function getRequiredEnv(name: "SUPABASE_URL" | "SUPABASE_ANON_KEY") {
  const value = process.env[name];

  if (!value) {
    throw new Error(`${name} is not set`);
  }

  return value;
}

function getRequiredServiceRoleKey() {
  const value = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!value) {
    throw new Error("SUPABASE_SERVICE_ROLE_KEY is not set");
  }

  return value;
}

function getSupabasePublishableOrAnonKey() {
  const publishableKey = process.env.SUPABASE_PUBLISHABLE_KEY;
  if (publishableKey) {
    return publishableKey;
  }

  const anonKey = process.env.SUPABASE_ANON_KEY;
  if (anonKey) {
    return anonKey;
  }

  throw new Error(
    "SUPABASE_PUBLISHABLE_KEY (preferred) or SUPABASE_ANON_KEY must be set",
  );
}

export function getSupabaseClient(): SupabaseClient<Database> {
  if (!supabaseClient) {
    supabaseClient = createClient<Database>(
      getRequiredEnv("SUPABASE_URL"),
      getSupabasePublishableOrAnonKey(),
    );
  }

  return supabaseClient;
}

export function getAuthedSupabaseClient(jwt: string): SupabaseClient<Database> {
  return createClient<Database>(
    getRequiredEnv("SUPABASE_URL"),
    getSupabasePublishableOrAnonKey(),
    { global: { headers: { Authorization: `Bearer ${jwt}` } } },
  );
}

export function getSupabaseServiceClient(): SupabaseClient<Database> {
  if (!supabaseServiceClient) {
    supabaseServiceClient = createClient<Database>(
      getRequiredEnv("SUPABASE_URL"),
      getRequiredServiceRoleKey(),
    );
  }

  return supabaseServiceClient;
}
