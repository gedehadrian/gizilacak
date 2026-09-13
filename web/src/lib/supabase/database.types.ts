/**
 * Tipe database GiziLacak (dirawat selaras migrasi).
 * Regenerasi resmi: npx supabase gen types typescript --project-id <ref>
 */
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export type Database = {
  public: {
    Tables: {
      profiles: { Row: { id: string; full_name: string; phone: string | null } };
      tenants: { Row: { id: string; name: string; sppg_code: string; status: string } };
      invoices: { Row: { id: string; tenant_id: string; status: string; total_rp: number } };
      payments: { Row: { id: string; invoice_id: string; status: string; amount_rp: number; environment: string } };
      deliveries: { Row: { id: string; tenant_id: string; school_id: string; status: string; code: string } };
    };
    Functions: {
      onboard_tenant: { Args: { _name: string; _sppg_code: string; _address: string; _billing_email: string }; Returns: string };
      onboard_school: { Args: { _name: string; _school_code: string; _address: string }; Returns: string };
      finalize_batch: { Args: { _batch_id: string }; Returns: undefined };
      dispatch_delivery: { Args: { _delivery_id: string }; Returns: string };
      submit_receipt: {
        Args: {
          _delivery_item_id: string;
          _accepted: number;
          _rejected: number;
          _reason: string;
          _note: string;
          _idempotency_key: string;
        };
        Returns: string;
      };
      create_invoice_from_plan: {
        Args: { _tenant_id: string; _plan_version_id: string; _purpose: string; _idempotency_key: string };
        Returns: string;
      };
      create_delivery_draft: {
        Args: { _tenant_id: string; _school_id: string; _items: Json; _idempotency_key: string };
        Returns: string;
      };
      activate_paid_invoice: { Args: { _invoice_id: string; _payment_id: string }; Returns: string };
      accept_invitation: { Args: { _token_hash: string }; Returns: Json };
    };
  };
};
