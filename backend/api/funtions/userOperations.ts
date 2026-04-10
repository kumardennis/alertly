import { SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseClient } from "../lib/supabase";
import { Database } from "../types/supabaseTypes";
import { UserFilter, UserInsert, UserUpdate } from "../types/userTypes";

const supabaseClient = getSupabaseClient();

export const getUser = async (
  filters: UserFilter,
  client?: SupabaseClient<Database>,
) => {
  // Fetch alerts from the database and return them

  const db = client ?? supabaseClient;
  const { data, error } = await db
    .from("users")
    .select("*, role:roles(*)") // Fetch related role information
    .match(filters);

  if (error) {
    console.error("Error fetching users:", error);
    throw new Error("Unable to fetch users");
  }

  return data;
};

export const createUser = async (userData: UserInsert) => {
  // Create a new user in the database

  const { data, error } = await supabaseClient
    .from("users")
    .insert(userData)
    .select("*, role:roles(*)") // Fetch related role information
    .single();

  if (error) {
    console.error("Error creating user:", error);
    throw new Error("Unable to create user");
  }

  return data;
};

export const updateUser = async (userData: UserUpdate) => {
  // Update an existing user in the database

  const { data, error } = await supabaseClient
    .from("users")
    .update(userData)
    .eq("id", Number(userData.id))
    .select("*, role:roles(*)") // Fetch related role information
    .single();

  if (error) {
    console.error("Error updating user:", error);
    throw new Error("Unable to update user");
  }

  return data;
};
