import { Tier } from "./alertTypes";
import { Tables, TablesInsert, TablesUpdate } from "./supabaseTypes";

export type User = Tables<"users">;
export type UserInsert = TablesInsert<"users">;
export type UserUpdate = TablesUpdate<"users">;

export type UserWithTier = User & {
  tierInfo?: Tier | null;
};

export type UserFilter = {
  id?: number;
  auth_id?: string;
};
