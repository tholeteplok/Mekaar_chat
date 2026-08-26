"use client";

import { useEffect, useState } from "react";
import { FileText, Filter, RefreshCw, ShieldCheck } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import {
  AuditLogTable,
  AuditLogItem,
} from "@/components/audit-log-table";

export default function AuditLogsPage() {
  const [logs, setLogs] = useState<AuditLogItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionFilter, setActionFilter] = useState<string>("ALL");

  const fetchAuditLogs = async () => {
    try {
      setLoading(true);
      const supabase = createClient();

      let query = supabase
        .from("admin_audit_logs")
        .select(`
          id,
          admin_id,
          action_type,
          target_user_id,
          reason,
          ip_address,
          metadata,
          created_at,
          admin:profiles!admin_audit_logs_admin_id_fkey(full_name),
          target:profiles!admin_audit_logs_target_user_id_fkey(full_name)
        `)
        .order("created_at", { ascending: false })
        .limit(100);

      if (actionFilter !== "ALL") {
        query = query.eq("action_type", actionFilter);
      }

      const { data, error } = await query;
      if (error) throw error;

      setLogs((data as any) || []);
    } catch (err) {
      console.error("[AuditLogs fetch error]", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAuditLogs();
  }, [actionFilter]);

  const actionFilterOptions = [
    { value: "ALL", label: "SEMUA AKSI" },
    { value: "SUSPEND", label: "PEMBEKUAN" },
    { value: "UNSUSPEND", label: "PELEPASAN BEKU" },
    { value: "ENABLE_LEGAL_HOLD", label: "AKTIFKAN LEGAL HOLD" },
    { value: "DISABLE_LEGAL_HOLD", label: "NONAKTIFKAN LEGAL HOLD" },
    { value: "PURGE", label: "PEMBERSIHAN" },
  ];

  return (
    <div className="space-y-6">
      {/* Judul & Penjelasan */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-2xl font-bold tracking-tight">Catatan Log Audit Admin (Permanen)</h1>
            <div className="flex items-center gap-1 px-2.5 py-0.5 rounded-full bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-xs font-semibold">
              <ShieldCheck className="w-3.5 h-3.5" />
              <span>Aturan Hanya-Tambah Aktif</span>
            </div>
          </div>
          <p className="text-sm text-muted-foreground mt-1">
            Catatan jejak audit tindakan administrator yang dilindungi aturan basis data permanen (tidak dapat diubah atau dihapus).
          </p>
        </div>

        <Button
          variant="outline"
          size="sm"
          onClick={fetchAuditLogs}
          disabled={loading}
          className="flex items-center gap-1.5 self-start md:self-auto"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? "animate-spin" : ""}`} />
          <span>Muat Ulang</span>
        </Button>
      </div>

      {/* Filter Tipe Aksi */}
      <div className="flex flex-wrap items-center gap-3 p-4 rounded-xl border border-border/80 bg-card/60">
        <div className="flex items-center gap-2 text-xs text-muted-foreground">
          <Filter className="w-3.5 h-3.5" />
          <span>Saring Tindakan:</span>
        </div>
        <div className="flex flex-wrap gap-1.5">
          {actionFilterOptions.map((act) => (
            <button
              key={act.value}
              onClick={() => setActionFilter(act.value)}
              className={`px-3 py-1 rounded-md text-xs font-medium transition-colors ${
                actionFilter === act.value
                  ? "bg-primary text-white"
                  : "bg-muted/40 text-muted-foreground hover:text-foreground"
              }`}
            >
              {act.label}
            </button>
          ))}
        </div>
      </div>

      {/* Tabel Log */}
      <AuditLogTable logs={logs} loading={loading} />
    </div>
  );
}
