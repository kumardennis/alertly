import { SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseClient } from "../lib/supabase";
import { AlertFilters, AlertInsert, AlertUpdate } from "../types/alertTypes";
import { Database } from "../types/supabaseTypes";

const supabaseClient = getSupabaseClient();

export const getAlerts = async (filters: AlertFilters) => {
  // Fetch alerts from the database and return them

  const { data, error } = await supabaseClient
    .from("alerts")
    .select("*, user:users(*), tierInfo:tiers(*)")
    .match(filters)
    .order("published_at", { ascending: false });

  if (error) {
    console.error("Error fetching alerts:", error);
    throw new Error("Unable to fetch alerts");
  }

  return data;
};

export const createAlert = async (
  alertData: AlertInsert,
  client: SupabaseClient<Database>,
) => {
  // Create a new alert in the database
  const { data, error } = await client
    .from("alerts")
    .insert(alertData)
    .select("*, user:users(*), tierInfo:tiers(*)")
    .single();

  if (error) {
    console.error("Error creating alert:", error);
    throw new Error("Unable to create alert");
  }

  return data;
};

export const updateAlert = async (
  alertId: number,
  alertData: AlertUpdate,
  client?: SupabaseClient<Database>,
) => {
  // Update an existing alert in the database

  const db = client ?? supabaseClient;
  const { data, error } = await db
    .from("alerts")
    .update(alertData)
    .eq("id", alertId)
    .select("*, user:users(*), tierInfo:tiers(*)")
    .single();

  if (error) {
    console.error("Error updating alert:", error);
    throw new Error("Unable to update alert");
  }

  return data;
};

export const deleteAlert = async (
  alertId: number,
  client?: SupabaseClient<Database>,
) => {
  const db = client ?? supabaseClient;
  const { error } = await db.from("alerts").delete().eq("id", alertId);

  if (error) {
    console.error("Error deleting alert:", error);
    throw new Error("Unable to delete alert");
  }
};
