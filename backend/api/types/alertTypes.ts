import { Tables, TablesInsert, TablesUpdate } from "./supabaseTypes";
import { User } from "./userTypes";

export type Role = Tables<"roles">;
export type RoleInsert = TablesInsert<"roles">;
export type RoleUpdate = TablesUpdate<"roles">;

export type Tier = Tables<"tiers">;
export type TierInsert = TablesInsert<"tiers">;
export type TierUpdate = TablesUpdate<"tiers">;

export type Alert = Tables<"alerts">;
export type AlertInsert = TablesInsert<"alerts">;
export type AlertUpdate = TablesUpdate<"alerts">;

export type AlertWithRelations = Alert & {
  user?: User | null;
  tierInfo?: Tier | null;
};

export type AlertFilters = {
  category?: string;
  status?: number;
  user_id?: number;
  flagged?: boolean;
  id?: number;
};

export enum AlertStatus {
  "pending" = "pending",
  "published" = "published",
  "rejected" = "rejected",
  "expired" = "expired",
  "resolved" = "resolved",
}

export enum AlertCategory {
  "emergency" = "emergency",
  "infrastructure" = "infrastructure",
  "crime" = "crime",
  "other" = "other",
  "civic" = "civic",
  "community" = "community",
  "weather" = "weather",
}

export const ALERT_QUEUE_NAME = "alert-jobs";
