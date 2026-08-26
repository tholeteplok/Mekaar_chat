"use client";

import { X, Shield, CheckCircle, Ban, Eye } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { formatDate } from "@/lib/utils";

export interface UserReport {
  id: string;
  reporter_id: string;
  reported_user_id: string;
  room_id: string | null;
  message_id: string | null;
  category: "spam" | "harassment" | "fake_sos" | "impersonation" | "other";
  reason: string;
  evidence_snapshot: string | null;
  status: "pending" | "investigating" | "resolved" | "rejected";
  created_at: string;
  reporter?: {
    full_name: string | null;
    username: string | null;
    email: string | null;
  } | null;
  reported?: {
    full_name: string | null;
    username: string | null;
    email: string | null;
    is_suspended?: boolean;
    legal_hold_active?: boolean;
  } | null;
}

interface ReportInspectorModalProps {
  report: UserReport | null;
  isOpen: boolean;
  onClose: () => void;
  onUpdateStatus: (reportId: string, status: UserReport["status"]) => Promise<void>;
  onTriggerSuspend: (targetUserId: string, reason: string) => void;
}

export function ReportInspectorModal({
  report,
  isOpen,
  onClose,
  onUpdateStatus,
  onTriggerSuspend,
}: ReportInspectorModalProps) {
  if (!isOpen || !report) return null;

  const categoryColorMap: Record<string, "default" | "destructive" | "warning" | "secondary"> = {
    fake_sos: "destructive",
    harassment: "destructive",
    spam: "warning",
    impersonation: "warning",
    other: "secondary",
  };

  const getCategoryLabel = (cat: string) => {
    switch (cat) {
      case "fake_sos":
        return "SOS PALSU";
      case "harassment":
        return "PELECEHAN";
      case "spam":
        return "SPAM";
      case "impersonation":
        return "PENIRUAN IDENTITAS";
      default:
        return "LAINNYA";
    }
  };

  const getStatusLabel = (st: string) => {
    switch (st) {
      case "pending":
        return "MENUNGGU";
      case "investigating":
        return "DALAM INVESTIGASI";
      case "resolved":
        return "SELESAI";
      case "rejected":
        return "DITOLAK";
      default:
        return st.toUpperCase();
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4 animate-in fade-in duration-200">
      <div className="bg-card border border-border/80 rounded-xl shadow-2xl max-w-2xl w-full max-h-[90vh] flex flex-col overflow-hidden">
        {/* Header */}
        <div className="p-6 border-b border-border/80 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-lg bg-primary/10 text-primary">
              <Shield className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-semibold text-lg text-foreground">
                Detail Laporan Pengguna
              </h3>
              <p className="text-xs text-muted-foreground">ID Laporan: {report.id}</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="text-muted-foreground hover:text-foreground transition-colors p-1.5 rounded-md hover:bg-muted"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Konten Detail */}
        <div className="p-6 overflow-y-auto space-y-6 text-sm flex-1">
          {/* Status & Kategori */}
          <div className="grid grid-cols-2 gap-4 bg-muted/20 p-4 rounded-lg border border-border/40">
            <div>
              <span className="text-xs text-muted-foreground block mb-1">
                Kategori Pelanggaran
              </span>
              <Badge variant={categoryColorMap[report.category] || "default"}>
                {getCategoryLabel(report.category)}
              </Badge>
            </div>
            <div>
              <span className="text-xs text-muted-foreground block mb-1">
                Status Penanganan
              </span>
              <Badge variant={report.status === "pending" ? "warning" : report.status === "investigating" ? "default" : report.status === "resolved" ? "success" : "secondary"}>
                {getStatusLabel(report.status)}
              </Badge>
            </div>
            <div>
              <span className="text-xs text-muted-foreground block mb-1">
                Waktu Pelaporan
              </span>
              <span className="text-foreground font-medium">
                {formatDate(report.created_at)}
              </span>
            </div>
            <div>
              <span className="text-xs text-muted-foreground block mb-1">
                Konteks Ruang Obrolan
              </span>
              <span className="text-xs font-mono text-muted-foreground">
                {report.room_id || "Tidak Ada"}
              </span>
            </div>
          </div>

          {/* Profil Terlapor & Pelapor */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="p-4 rounded-lg border border-border/50 bg-background/50">
              <span className="text-xs font-semibold text-muted-foreground block mb-2">
                PELAPOR
              </span>
              <p className="font-medium text-foreground">
                {report.reporter?.full_name || (report.reporter?.username ? `@${report.reporter.username}` : "Nama tidak tersedia")}
              </p>
              <p className="text-xs text-muted-foreground font-mono mt-1">
                Surel: {report.reporter?.email || "-"}
              </p>
              <p className="text-[10px] text-muted-foreground/60 font-mono">
                UID: {report.reporter_id}
              </p>
            </div>

            <div className="p-4 rounded-lg border border-red-500/20 bg-red-950/10">
              <span className="text-xs font-semibold text-red-400 block mb-2">
                TERLAPOR
              </span>
              <p className="font-medium text-foreground">
                {report.reported?.full_name || (report.reported?.username ? `@${report.reported.username}` : "Nama tidak tersedia")}
              </p>
              <p className="text-xs text-muted-foreground font-mono mt-1">
                Surel: {report.reported?.email || "-"}
              </p>
              <p className="text-[10px] text-muted-foreground/60 font-mono">
                UID: {report.reported_user_id}
              </p>
              {report.reported?.is_suspended && (
                <Badge variant="destructive" className="mt-2 text-[10px]">
                  Saat ini dibekukan
                </Badge>
              )}
            </div>
          </div>

          {/* Alasan Pelaporan */}
          <div>
            <span className="text-xs font-semibold text-muted-foreground block mb-1.5">
              Alasan Pelapor
            </span>
            <div className="p-3.5 rounded-lg bg-muted/40 border border-border/40 text-foreground">
              {report.reason}
            </div>
          </div>

          {/* Cuplikan Bukti Pesan */}
          <div>
            <div className="flex items-center justify-between mb-1.5">
              <span className="text-xs font-semibold text-muted-foreground flex items-center gap-1.5">
                <Eye className="w-3.5 h-3.5" />
                Cuplikan Bukti Pesan (E2EE)
              </span>
              <span className="text-[10px] text-muted-foreground">
                Teks polos aman (Terlindungi dari XSS)
              </span>
            </div>
            {report.evidence_snapshot ? (
              <pre className="p-4 rounded-lg bg-black/60 border border-border/60 text-xs font-mono text-emerald-400 whitespace-pre-wrap break-words max-h-48 overflow-y-auto">
                {report.evidence_snapshot}
              </pre>
            ) : (
              <div className="p-4 rounded-lg bg-muted/20 border border-border/40 text-xs text-muted-foreground italic">
                Tidak ada cuplikan bukti teks yang dilampirkan oleh pelapor.
              </div>
            )}
          </div>
        </div>

        {/* Tombol Tindakan */}
        <div className="p-4 border-t border-border/80 bg-muted/10 flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => onUpdateStatus(report.id, "investigating")}
              disabled={report.status === "investigating"}
            >
              Investigasi
            </Button>
            <Button
              variant="outline"
              size="sm"
              className="text-emerald-400 hover:text-emerald-300"
              onClick={() => onUpdateStatus(report.id, "resolved")}
              disabled={report.status === "resolved"}
            >
              <CheckCircle className="w-3.5 h-3.5 mr-1" />
              Selesaikan
            </Button>
            <Button
              variant="outline"
              size="sm"
              className="text-muted-foreground"
              onClick={() => onUpdateStatus(report.id, "rejected")}
              disabled={report.status === "rejected"}
            >
              Tolak
            </Button>
          </div>

          <div className="flex items-center gap-2">
            <Button
              variant="destructive"
              size="sm"
              onClick={() => {
                onTriggerSuspend(
                  report.reported_user_id,
                  `Ditindaklanjuti dari Laporan #${report.id.slice(0, 8)} (${getCategoryLabel(report.category)}): ${report.reason}`
                );
              }}
            >
              <Ban className="w-3.5 h-3.5 mr-1.5" />
              Bekukan Akun Terlapor
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}
