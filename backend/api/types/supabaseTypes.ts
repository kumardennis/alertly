export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      alerts: {
        Row: {
          body: string | null
          category: string
          created_at: string
          flagged: boolean
          id: number
          location: unknown
          published_at: string | null
          radius_m: number | null
          status: string | null
          tier: number | null
          title: string | null
          user_id: number | null
        }
        Insert: {
          body?: string | null
          category?: string
          created_at?: string
          flagged?: boolean
          id?: number
          location: unknown
          published_at?: string | null
          radius_m?: number | null
          status?: string | null
          tier?: number | null
          title?: string | null
          user_id?: number | null
        }
        Update: {
          body?: string | null
          category?: string
          created_at?: string
          flagged?: boolean
          id?: number
          location?: unknown
          published_at?: string | null
          radius_m?: number | null
          status?: string | null
          tier?: number | null
          title?: string | null
          user_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "alerts_tier_fkey"
            columns: ["tier"]
            isOneToOne: false
            referencedRelation: "tiers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "alerts_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      alerts_verifications: {
        Row: {
          alert_id: number | null
          created_at: string
          id: number
          user_id: number | null
          verified: boolean | null
        }
        Insert: {
          alert_id?: number | null
          created_at?: string
          id?: number
          user_id?: number | null
          verified?: boolean | null
        }
        Update: {
          alert_id?: number | null
          created_at?: string
          id?: number
          user_id?: number | null
          verified?: boolean | null
        }
        Relationships: [
          {
            foreignKeyName: "alerts_verifications_alert_id_fkey"
            columns: ["alert_id"]
            isOneToOne: false
            referencedRelation: "alerts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "alerts_verifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      roles: {
        Row: {
          created_at: string
          id: number
          role: string | null
        }
        Insert: {
          created_at?: string
          id?: number
          role?: string | null
        }
        Update: {
          created_at?: string
          id?: number
          role?: string | null
        }
        Relationships: []
      }
      tiers: {
        Row: {
          created_at: string
          id: number
          priority: string | null
          tier: string | null
        }
        Insert: {
          created_at?: string
          id?: number
          priority?: string | null
          tier?: string | null
        }
        Update: {
          created_at?: string
          id?: number
          priority?: string | null
          tier?: string | null
        }
        Relationships: []
      }
      users: {
        Row: {
          age: number | null
          auth_id: string | null
          created_at: string
          first_name: string | null
          id: number
          is_age_verified: boolean | null
          last_name: string | null
          location: unknown
          location_updated_at: string | null
          preferred_radius_m: number
          rep_score: number | null
          role: number | null
          username: string
        }
        Insert: {
          age?: number | null
          auth_id?: string | null
          created_at?: string
          first_name?: string | null
          id?: number
          is_age_verified?: boolean | null
          last_name?: string | null
          location?: unknown
          location_updated_at?: string | null
          preferred_radius_m?: number
          rep_score?: number | null
          role?: number | null
          username: string
        }
        Update: {
          age?: number | null
          auth_id?: string | null
          created_at?: string
          first_name?: string | null
          id?: number
          is_age_verified?: boolean | null
          last_name?: string | null
          location?: unknown
          location_updated_at?: string | null
          preferred_radius_m?: number
          rep_score?: number | null
          role?: number | null
          username?: string
        }
        Relationships: [
          {
            foreignKeyName: "users_role_fkey"
            columns: ["role"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "users_tier_fkey"
            columns: ["role"]
            isOneToOne: false
            referencedRelation: "tiers"
            referencedColumns: ["id"]
          },
        ]
      }
      users_devices: {
        Row: {
          created_at: string
          fcm_token: string
          id: number
          platform: string | null
          updated_at: string | null
          user_id: number | null
        }
        Insert: {
          created_at?: string
          fcm_token: string
          id?: number
          platform?: string | null
          updated_at?: string | null
          user_id?: number | null
        }
        Update: {
          created_at?: string
          fcm_token?: string
          id?: number
          platform?: string | null
          updated_at?: string | null
          user_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "users_devices_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      users_received_alerts: {
        Row: {
          alert_id: number | null
          created_at: string
          id: number
          receiver_id: number | null
        }
        Insert: {
          alert_id?: number | null
          created_at?: string
          id?: number
          receiver_id?: number | null
        }
        Update: {
          alert_id?: number | null
          created_at?: string
          id?: number
          receiver_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "users_received_alerts_alert_id_fkey"
            columns: ["alert_id"]
            isOneToOne: false
            referencedRelation: "alerts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "users_received_alerts_receiver_id_fkey"
            columns: ["receiver_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      get_alert_location: {
        Args: { p_alert_id: number }
        Returns: {
          alert_id: number
          latitude: number
          longitude: number
        }[]
      }
      get_alert_recipient_user_ids: {
        Args: { p_alert_id: number }
        Returns: {
          distance_m: number
          user_id: number
        }[]
      }
      parse_location_binary: {
        Args: { p_location: string }
        Returns: {
          latitude: number
          longitude: number
        }[]
      }
      parse_location_wkt: {
        Args: { p_location_text: string }
        Returns: {
          latitude: number
          longitude: number
        }[]
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
