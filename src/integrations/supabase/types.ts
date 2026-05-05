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
      balance_adjustments: {
        Row: {
          admin_id: string
          asset: string
          created_at: string
          delta: number
          id: string
          reason: string | null
          user_id: string
        }
        Insert: {
          admin_id: string
          asset: string
          created_at?: string
          delta: number
          id?: string
          reason?: string | null
          user_id: string
        }
        Update: {
          admin_id?: string
          asset?: string
          created_at?: string
          delta?: number
          id?: string
          reason?: string | null
          user_id?: string
        }
        Relationships: []
      }
      copy_experts: {
        Row: {
          active: boolean
          avatar_url: string | null
          bio: string | null
          created_at: string
          followers: number
          id: string
          name: string
          win_rate: number | null
        }
        Insert: {
          active?: boolean
          avatar_url?: string | null
          bio?: string | null
          created_at?: string
          followers?: number
          id?: string
          name: string
          win_rate?: number | null
        }
        Update: {
          active?: boolean
          avatar_url?: string | null
          bio?: string | null
          created_at?: string
          followers?: number
          id?: string
          name?: string
          win_rate?: number | null
        }
        Relationships: []
      }
      deposits: {
        Row: {
          admin_note: string | null
          amount: number
          coin: string
          created_at: string
          fee_pct: number | null
          id: string
          pay_amount: number | null
          pay_coin: string | null
          processed_at: string | null
          proof_url: string | null
          rate_used: number | null
          status: Database["public"]["Enums"]["tx_status"]
          tx_hash: string | null
          usd_amount: number | null
          usd_credited: number | null
          user_id: string
        }
        Insert: {
          admin_note?: string | null
          amount: number
          coin: string
          created_at?: string
          fee_pct?: number | null
          id?: string
          pay_amount?: number | null
          pay_coin?: string | null
          processed_at?: string | null
          proof_url?: string | null
          rate_used?: number | null
          status?: Database["public"]["Enums"]["tx_status"]
          tx_hash?: string | null
          usd_amount?: number | null
          usd_credited?: number | null
          user_id: string
        }
        Update: {
          admin_note?: string | null
          amount?: number
          coin?: string
          created_at?: string
          fee_pct?: number | null
          id?: string
          pay_amount?: number | null
          pay_coin?: string | null
          processed_at?: string | null
          proof_url?: string | null
          rate_used?: number | null
          status?: Database["public"]["Enums"]["tx_status"]
          tx_hash?: string | null
          usd_amount?: number | null
          usd_credited?: number | null
          user_id?: string
        }
        Relationships: []
      }
      email_logs: {
        Row: {
          created_at: string
          error: string | null
          id: string
          recipient: string
          status: string
          subject: string | null
          template_key: string | null
        }
        Insert: {
          created_at?: string
          error?: string | null
          id?: string
          recipient: string
          status: string
          subject?: string | null
          template_key?: string | null
        }
        Update: {
          created_at?: string
          error?: string | null
          id?: string
          recipient?: string
          status?: string
          subject?: string | null
          template_key?: string | null
        }
        Relationships: []
      }
      email_settings: {
        Row: {
          enabled: boolean
          from_email: string | null
          from_name: string | null
          id: number
          mail_driver: string
          reply_to: string | null
          smtp_encryption: string
          smtp_host: string | null
          smtp_pass: string | null
          smtp_port: number | null
          smtp_user: string | null
          updated_at: string
        }
        Insert: {
          enabled?: boolean
          from_email?: string | null
          from_name?: string | null
          id?: number
          mail_driver?: string
          reply_to?: string | null
          smtp_encryption?: string
          smtp_host?: string | null
          smtp_pass?: string | null
          smtp_port?: number | null
          smtp_user?: string | null
          updated_at?: string
        }
        Update: {
          enabled?: boolean
          from_email?: string | null
          from_name?: string | null
          id?: number
          mail_driver?: string
          reply_to?: string | null
          smtp_encryption?: string
          smtp_host?: string | null
          smtp_pass?: string | null
          smtp_port?: number | null
          smtp_user?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      email_templates: {
        Row: {
          active: boolean
          body: string
          created_at: string
          id: string
          key: string
          name: string
          subject: string
          updated_at: string
        }
        Insert: {
          active?: boolean
          body: string
          created_at?: string
          id?: string
          key: string
          name: string
          subject: string
          updated_at?: string
        }
        Update: {
          active?: boolean
          body?: string
          created_at?: string
          id?: string
          key?: string
          name?: string
          subject?: string
          updated_at?: string
        }
        Relationships: []
      }
      exchange_transactions: {
        Row: {
          created_at: string
          fee_amount: number
          fee_pct: number
          from_amount: number
          from_asset: string
          id: string
          kind: string
          note: string | null
          rate: number
          status: string
          to_amount: number
          to_asset: string
          user_id: string
        }
        Insert: {
          created_at?: string
          fee_amount?: number
          fee_pct?: number
          from_amount: number
          from_asset: string
          id?: string
          kind: string
          note?: string | null
          rate: number
          status?: string
          to_amount: number
          to_asset: string
          user_id: string
        }
        Update: {
          created_at?: string
          fee_amount?: number
          fee_pct?: number
          from_amount?: number
          from_asset?: string
          id?: string
          kind?: string
          note?: string | null
          rate?: number
          status?: string
          to_amount?: number
          to_asset?: string
          user_id?: string
        }
        Relationships: []
      }
      fiat_balances: {
        Row: {
          available: number
          currency: string
          id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          available?: number
          currency?: string
          id?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          available?: number
          currency?: string
          id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      impersonation_log: {
        Row: {
          admin_email: string | null
          admin_id: string
          ended_at: string | null
          id: string
          ip: string | null
          started_at: string
          target_email: string | null
          target_user_id: string
          user_agent: string | null
        }
        Insert: {
          admin_email?: string | null
          admin_id: string
          ended_at?: string | null
          id?: string
          ip?: string | null
          started_at?: string
          target_email?: string | null
          target_user_id: string
          user_agent?: string | null
        }
        Update: {
          admin_email?: string | null
          admin_id?: string
          ended_at?: string | null
          id?: string
          ip?: string | null
          started_at?: string
          target_email?: string | null
          target_user_id?: string
          user_agent?: string | null
        }
        Relationships: []
      }
      kyc_records: {
        Row: {
          admin_note: string | null
          created_at: string
          doc_type: string
          doc_url: string | null
          full_address: string | null
          id: string
          id_back_url: string | null
          id_front_url: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          selfie_url: string | null
          status: Database["public"]["Enums"]["kyc_status"]
          user_id: string
        }
        Insert: {
          admin_note?: string | null
          created_at?: string
          doc_type: string
          doc_url?: string | null
          full_address?: string | null
          id?: string
          id_back_url?: string | null
          id_front_url?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          selfie_url?: string | null
          status?: Database["public"]["Enums"]["kyc_status"]
          user_id: string
        }
        Update: {
          admin_note?: string | null
          created_at?: string
          doc_type?: string
          doc_url?: string | null
          full_address?: string | null
          id?: string
          id_back_url?: string | null
          id_front_url?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          selfie_url?: string | null
          status?: Database["public"]["Enums"]["kyc_status"]
          user_id?: string
        }
        Relationships: []
      }
      login_history: {
        Row: {
          at: string
          id: string
          ip: string | null
          user_agent: string | null
          user_id: string
        }
        Insert: {
          at?: string
          id?: string
          ip?: string | null
          user_agent?: string | null
          user_id: string
        }
        Update: {
          at?: string
          id?: string
          ip?: string | null
          user_agent?: string | null
          user_id?: string
        }
        Relationships: []
      }
      market_assets: {
        Row: {
          active: boolean
          coingecko_id: string | null
          created_at: string
          deposit_address: string | null
          icon_url: string | null
          id: string
          name: string
          sort_order: number
          symbol: string
        }
        Insert: {
          active?: boolean
          coingecko_id?: string | null
          created_at?: string
          deposit_address?: string | null
          icon_url?: string | null
          id?: string
          name: string
          sort_order?: number
          symbol: string
        }
        Update: {
          active?: boolean
          coingecko_id?: string | null
          created_at?: string
          deposit_address?: string | null
          icon_url?: string | null
          id?: string
          name?: string
          sort_order?: number
          symbol?: string
        }
        Relationships: []
      }
      notifications: {
        Row: {
          audience_count: number | null
          body: string | null
          broadcast: boolean
          created_at: string
          id: string
          read: boolean
          segment: string | null
          title: string
          user_id: string | null
        }
        Insert: {
          audience_count?: number | null
          body?: string | null
          broadcast?: boolean
          created_at?: string
          id?: string
          read?: boolean
          segment?: string | null
          title: string
          user_id?: string | null
        }
        Update: {
          audience_count?: number | null
          body?: string | null
          broadcast?: boolean
          created_at?: string
          id?: string
          read?: boolean
          segment?: string | null
          title?: string
          user_id?: string | null
        }
        Relationships: []
      }
      profiles: {
        Row: {
          address_line1: string | null
          address_line2: string | null
          avatar_url: string | null
          banned: boolean
          banned_reason: string | null
          city: string | null
          country: string | null
          country_code: string | null
          created_at: string
          dob: string | null
          email: string | null
          email_verified: boolean
          first_name: string | null
          full_name: string | null
          id: string
          id_number: string | null
          kyc_status: Database["public"]["Enums"]["kyc_status"]
          last_name: string | null
          mobile_verified: boolean
          notes: string | null
          phone: string | null
          postal_code: string | null
          state: string | null
          two_factor_enabled: boolean
          updated_at: string
          username: string | null
        }
        Insert: {
          address_line1?: string | null
          address_line2?: string | null
          avatar_url?: string | null
          banned?: boolean
          banned_reason?: string | null
          city?: string | null
          country?: string | null
          country_code?: string | null
          created_at?: string
          dob?: string | null
          email?: string | null
          email_verified?: boolean
          first_name?: string | null
          full_name?: string | null
          id: string
          id_number?: string | null
          kyc_status?: Database["public"]["Enums"]["kyc_status"]
          last_name?: string | null
          mobile_verified?: boolean
          notes?: string | null
          phone?: string | null
          postal_code?: string | null
          state?: string | null
          two_factor_enabled?: boolean
          updated_at?: string
          username?: string | null
        }
        Update: {
          address_line1?: string | null
          address_line2?: string | null
          avatar_url?: string | null
          banned?: boolean
          banned_reason?: string | null
          city?: string | null
          country?: string | null
          country_code?: string | null
          created_at?: string
          dob?: string | null
          email?: string | null
          email_verified?: boolean
          first_name?: string | null
          full_name?: string | null
          id?: string
          id_number?: string | null
          kyc_status?: Database["public"]["Enums"]["kyc_status"]
          last_name?: string | null
          mobile_verified?: boolean
          notes?: string | null
          phone?: string | null
          postal_code?: string | null
          state?: string | null
          two_factor_enabled?: boolean
          updated_at?: string
          username?: string | null
        }
        Relationships: []
      }
      signals: {
        Row: {
          created_at: string
          created_by: string | null
          entry: number
          id: string
          notes: string | null
          pair: string
          side: Database["public"]["Enums"]["trade_side"]
          stop: number | null
          target: number | null
          title: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          entry: number
          id?: string
          notes?: string | null
          pair: string
          side: Database["public"]["Enums"]["trade_side"]
          stop?: number | null
          target?: number | null
          title: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          entry?: number
          id?: string
          notes?: string | null
          pair?: string
          side?: Database["public"]["Enums"]["trade_side"]
          stop?: number | null
          target?: number | null
          title?: string
        }
        Relationships: []
      }
      staking_plans: {
        Row: {
          active: boolean
          apy: number
          coin: string
          created_at: string
          description: string | null
          fixed_amount: number | null
          id: string
          is_usd: boolean
          lock_days: number
          max_amount: number | null
          min_amount: number
          name: string
          updated_at: string
        }
        Insert: {
          active?: boolean
          apy: number
          coin: string
          created_at?: string
          description?: string | null
          fixed_amount?: number | null
          id?: string
          is_usd?: boolean
          lock_days: number
          max_amount?: number | null
          min_amount?: number
          name: string
          updated_at?: string
        }
        Update: {
          active?: boolean
          apy?: number
          coin?: string
          created_at?: string
          description?: string | null
          fixed_amount?: number | null
          id?: string
          is_usd?: boolean
          lock_days?: number
          max_amount?: number | null
          min_amount?: number
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      system_settings: {
        Row: {
          key: string
          updated_at: string
          value: Json
        }
        Insert: {
          key: string
          updated_at?: string
          value: Json
        }
        Update: {
          key?: string
          updated_at?: string
          value?: Json
        }
        Relationships: []
      }
      trade_records: {
        Row: {
          amount: number
          closed_at: string | null
          entry_price: number
          exit_price: number | null
          id: string
          notes: string | null
          opened_at: string
          pair: string
          pnl: number | null
          side: Database["public"]["Enums"]["trade_side"]
          status: Database["public"]["Enums"]["trade_status"]
          user_id: string | null
        }
        Insert: {
          amount: number
          closed_at?: string | null
          entry_price: number
          exit_price?: number | null
          id?: string
          notes?: string | null
          opened_at?: string
          pair: string
          pnl?: number | null
          side: Database["public"]["Enums"]["trade_side"]
          status?: Database["public"]["Enums"]["trade_status"]
          user_id?: string | null
        }
        Update: {
          amount?: number
          closed_at?: string | null
          entry_price?: number
          exit_price?: number | null
          id?: string
          notes?: string | null
          opened_at?: string
          pair?: string
          pnl?: number | null
          side?: Database["public"]["Enums"]["trade_side"]
          status?: Database["public"]["Enums"]["trade_status"]
          user_id?: string | null
        }
        Relationships: []
      }
      transaction_history: {
        Row: {
          amount: number | null
          coin: string | null
          created_at: string
          description: string | null
          id: string
          ref_id: string | null
          status: Database["public"]["Enums"]["tx_status"] | null
          type: string
          user_id: string
        }
        Insert: {
          amount?: number | null
          coin?: string | null
          created_at?: string
          description?: string | null
          id?: string
          ref_id?: string | null
          status?: Database["public"]["Enums"]["tx_status"] | null
          type: string
          user_id: string
        }
        Update: {
          amount?: number | null
          coin?: string | null
          created_at?: string
          description?: string | null
          id?: string
          ref_id?: string | null
          status?: Database["public"]["Enums"]["tx_status"] | null
          type?: string
          user_id?: string
        }
        Relationships: []
      }
      user_roles: {
        Row: {
          created_at: string
          id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
      user_signals: {
        Row: {
          created_at: string
          id: string
          read: boolean
          signal_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          read?: boolean
          signal_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          read?: boolean
          signal_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_signals_signal_id_fkey"
            columns: ["signal_id"]
            isOneToOne: false
            referencedRelation: "signals"
            referencedColumns: ["id"]
          },
        ]
      }
      user_stakes: {
        Row: {
          amount: number
          apy: number
          coin: string
          created_at: string
          ends_at: string
          id: string
          is_usd: boolean
          plan_id: string
          reward_earned: number
          started_at: string
          status: Database["public"]["Enums"]["stake_status"]
          user_id: string
        }
        Insert: {
          amount: number
          apy: number
          coin: string
          created_at?: string
          ends_at: string
          id?: string
          is_usd?: boolean
          plan_id: string
          reward_earned?: number
          started_at?: string
          status?: Database["public"]["Enums"]["stake_status"]
          user_id: string
        }
        Update: {
          amount?: number
          apy?: number
          coin?: string
          created_at?: string
          ends_at?: string
          id?: string
          is_usd?: boolean
          plan_id?: string
          reward_earned?: number
          started_at?: string
          status?: Database["public"]["Enums"]["stake_status"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_stakes_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "staking_plans"
            referencedColumns: ["id"]
          },
        ]
      }
      wallet_balances: {
        Row: {
          available: number
          coin: string
          id: string
          staked: number
          updated_at: string
          user_id: string
        }
        Insert: {
          available?: number
          coin: string
          id?: string
          staked?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          available?: number
          coin?: string
          id?: string
          staked?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      withdrawals: {
        Row: {
          address: string
          admin_note: string | null
          amount: number
          coin: string
          created_at: string
          fee: number
          fee_pct: number | null
          id: string
          payout_amount: number | null
          payout_coin: string | null
          processed_at: string | null
          rate_used: number | null
          status: Database["public"]["Enums"]["tx_status"]
          usd_amount: number | null
          user_id: string
        }
        Insert: {
          address: string
          admin_note?: string | null
          amount: number
          coin: string
          created_at?: string
          fee?: number
          fee_pct?: number | null
          id?: string
          payout_amount?: number | null
          payout_coin?: string | null
          processed_at?: string | null
          rate_used?: number | null
          status?: Database["public"]["Enums"]["tx_status"]
          usd_amount?: number | null
          user_id: string
        }
        Update: {
          address?: string
          admin_note?: string | null
          amount?: number
          coin?: string
          created_at?: string
          fee?: number
          fee_pct?: number | null
          id?: string
          payout_amount?: number | null
          payout_coin?: string | null
          processed_at?: string | null
          rate_used?: number | null
          status?: Database["public"]["Enums"]["tx_status"]
          usd_amount?: number | null
          user_id?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      admin_adjust_balance: {
        Args: {
          _asset: string
          _delta: number
          _reason?: string
          _target: string
        }
        Returns: string
      }
      execute_exchange: {
        Args: {
          _fee_pct: number
          _from_amount: number
          _from_asset: string
          _rate: number
          _to_asset: string
        }
        Returns: string
      }
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
      lookup_email_for_login: { Args: { _identifier: string }; Returns: string }
      record_login: { Args: { _ip?: string; _ua?: string }; Returns: undefined }
      send_notification_segment: {
        Args: {
          _body: string
          _segment: string
          _target_user?: string
          _title: string
        }
        Returns: number
      }
      set_username: { Args: { _username: string }; Returns: boolean }
      update_price_cache: { Args: { _prices: Json }; Returns: undefined }
    }
    Enums: {
      app_role: "admin" | "user"
      kyc_status: "none" | "pending" | "approved" | "rejected" | "unverified"
      stake_status: "active" | "completed" | "cancelled"
      trade_side: "buy" | "sell" | "long" | "short"
      trade_status: "open" | "closed" | "cancelled"
      tx_status: "pending" | "approved" | "rejected" | "completed" | "cancelled"
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
    Enums: {
      app_role: ["admin", "user"],
      kyc_status: ["none", "pending", "approved", "rejected", "unverified"],
      stake_status: ["active", "completed", "cancelled"],
      trade_side: ["buy", "sell", "long", "short"],
      trade_status: ["open", "closed", "cancelled"],
      tx_status: ["pending", "approved", "rejected", "completed", "cancelled"],
    },
  },
} as const
