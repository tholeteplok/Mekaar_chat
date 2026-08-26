"use client";

import { useEffect, useState } from "react";
import { Flag, Filter, Eye, Ban, CheckCircle, RefreshCw } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  ReportInspectorModal,
  UserReport,
} from "@/components/report-inspector-modal";
import { SuspendUserModal } from "@/components/user-action-dialogs";
import { formatDate } from "@/lib/utils";

export default function ReportsManagementPage() {
  const [reports, setReports] = useState<UserReport[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [categoryFilter, setCategoryFilter] = useState<string>("all");

  // State Modal Detail Inspeksi
  const [selectedReport, setSelectedReport] = useState<UserReport | null>(null);
  const [isInspectorOpen, setIsInspectorOpen] = useState(false);

  // State Modal Pembekuan Akun
  const [suspendTargetId, setSuspendTargetId] = useState<string | null>(null);
  const [suspendTargetName, setSuspendTargetName] = useState<string>("");
  const [isSuspendModalOpen, setIsSuspendModalOpen] = useState(false);

  const fetchReports = async () => {
    try {
      setLoading(true);
      const supabase = createClient();

      let query = supabase
        .from("user_reports")
        .select(`
          id,
          reporter_id,
          reported_user_id,
          room_id,
          message_id,
          category,
          reason,
          evidence_snapshot,
          status,
          created_at,
          reporter:profiles!user_reports_reporter_id_fkey(full_name, username, email),
          reported:profiles!user_reports_reported_user_id_fkey(full_name, username, email, is_suspended, legal_hold_active)
        `)
        .order("created_at", { ascending: false });

      if (statusFilter !== "all") {
        query = query.eq("status", statusFilter);
      }
      if (categoryFilter !== "all") {
        query = query.eq("category", categoryFilter);
      }

      const { data, error } = await query;
      if (error) throw error;

      setReports((data as any) || []);
    } catch (err) {
      console.error("[Reports fetch error]", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchReports();
  }, [statusFilter, categoryFilter]);

  const handleUpdateStatus = async (
    reportId: string,
    newStatus: UserReport["status"]
  ) => {
    try {
      const supabase = createClient();
      const { error } = await supabase
        .from("user_reports")
        .update({ status: newStatus })
        .eq("id", reportId);

      if (error) throw error;

      // Update state lokal
      setReports((prev) =>
        prev.map((r) => (r.id === reportId ? { ...r, status: newStatus } : r))
      );
      if (selectedReport?.id === reportId) {
        setSelectedReport((prev) => (prev ? { ...prev, status: newStatus } : null));
      }
    } catch (err: any) {
      alert("Gagal memperbarui status laporan: " + err.message);
    }
  };

  const handleTriggerSuspend = (targetUserId: string, reason: string) => {
    const reportItem = reports.find((r) => r.reported_user_id === targetUserId);
    setSuspendTargetId(targetUserId);
    setSuspendTargetName(
      reportItem?.reported?.full_name ||
        (reportItem?.reported?.username ? `@${reportItem.reported.username}` : targetUserId)
    );
    setIsSuspendModalOpen(true);
  };

  const handleConfirmSuspend = async (targetUserId: string, reason: string) => {
    const res = await fetch("/api/admin/suspend", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ targetUserId, reason }),
    });

    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.error || "Gagal membekukan akun target.");
    }

    alert("Akun berhasil dibekukan dan dicatat ke Catatan Audit.");
    fetchReports();
  };

  const statusOptions = [
    { value: "all", label: "SEMUA STATUS" },
    { value: "pending", label: "MENUNGGU" },
    { value: "investigating", label: "INVESTIGASI" },
    { value: "resolved", label: "SELESAI" },
    { value: "rejected", label: "DITOLAK" },
  ];

  const categoryOptions = [
    { value: "all", label: "SEMUA KATEGORI" },
    { value: "fake_sos", label: "SOS PALSU" },
    { value: "harassment", label: "PELECEHAN" },
    { value: "spam", label: "SPAM" },
    { value: "impersonation", label: "PENIRUAN IDENTITAS" },
    { value: "other", label: "LAINNYA" },
  ];

  const getCategoryLabel = (category: string) => {
    switch (category) {
      case "fake_sos":
        return "SOS PALSU";
      case "harassment":
        return "PELECEHAN";
      case "spam":
        return "SPAM";
      case "impersonation":
        return "PENIRUAN";
      default:
        return "LAINNYA";
    }
  };

  const getStatusLabel = (status: string) => {
    switch (status) {
      case "pending":
        return "Menunggu";
      case "investigating":
        return "Investigasi";
      case "resolved":
        return "Selesai";
      case "rejected":
        return "Ditolak";
      default:
        return status;
    }
  };

  return (
    <div className="space-y-6">
      {/* Judul & Deskripsi */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Antrean Pelaporan Pengguna</h1>
          <p className="text-sm text-muted-foreground mt-1">
            Tinjau laporan pelanggaran, periksa cuplikan bukti sukarela (E2EE), dan ambil tindakan moderasi.
          </p>
        </div>

        <Button
          variant="outline"
          size="sm"
          onClick={fetchReports}
          disabled={loading}
          className="flex items-center gap-1.5 self-start md:self-auto"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? "animate-spin" : ""}`} />
          <span>Muat Ulang</span>
        </Button>
      </div>

      {/* Filter Penyaringan */}
      <div className="flex flex-wrap items-center gap-3 p-4 rounded-xl border border-border/80 bg-card/60">
        <div className="flex items-center gap-2 text-xs text-muted-foreground">
          <Filter className="w-3.5 h-3.5" />
          <span>Status:</span>
        </div>
        <div className="flex flex-wrap gap-1.5">
          {statusOptions.map((st) => (
            <button
              key={st.value}
              onClick={() => setStatusFilter(st.value)}
              className={`px-3 py-1 rounded-md text-xs font-medium transition-colors ${
                statusFilter === st.value
                  ? "bg-primary text-white"
                  : "bg-muted/40 text-muted-foreground hover:text-foreground"
              }`}
            >
              {st.label}
            </button>
          ))}
        </div>

        <div className="h-4 w-[1px] bg-border/80 mx-2 hidden sm:block" />

        <div className="flex items-center gap-2 text-xs text-muted-foreground">
          <span>Kategori:</span>
        </div>
        <div className="flex flex-wrap gap-1.5">
          {categoryOptions.map((cat) => (
            <button
              key={cat.value}
              onClick={() => setCategoryFilter(cat.value)}
              className={`px-3 py-1 rounded-md text-xs font-medium transition-colors ${
                categoryFilter === cat.value
                  ? "bg-secondary text-secondary-foreground"
                  : "bg-muted/40 text-muted-foreground hover:text-foreground"
              }`}
            >
              {cat.label}
            </button>
          ))}
        </div>
      </div>

      {/* Tabel Laporan */}
      <div className="rounded-xl border border-border/80 bg-card overflow-hidden">
        {loading ? (
          <div className="p-8 text-center text-sm text-muted-foreground">
            Memuat daftar laporan...
          </div>
        ) : reports.length === 0 ? (
          <div className="p-8 text-center text-sm text-muted-foreground">
            Tidak ada laporan yang sesuai dengan penyaringan.
          </div>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="w-[160px]">Waktu Pelaporan</TableHead>
                <TableHead>Kategori</TableHead>
                <TableHead>Pelapor</TableHead>
                <TableHead>Terlapor</TableHead>
                <TableHead>Alasan Singkat</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="text-right">Tindakan</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {reports.map((report) => (
                <TableRow key={report.id}>
                  <TableCell className="text-xs font-mono text-muted-foreground">
                    {formatDate(report.created_at)}
                  </TableCell>
                  <TableCell>
                    <Badge
                      variant={
                        report.category === "fake_sos"
                          ? "destructive"
                          : report.category === "harassment"
                          ? "destructive"
                          : "warning"
                      }
                    >
                      {getCategoryLabel(report.category)}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-sm font-medium">
                    {report.reporter?.full_name || (report.reporter?.username ? `@${report.reporter.username}` : "Pelapor")}
                  </TableCell>
                  <TableCell className="text-sm">
                    <div className="font-medium text-foreground">
                      {report.reported?.full_name || (report.reported?.username ? `@${report.reported.username}` : "Terlapor")}
                    </div>
                    {report.reported?.is_suspended && (
                      <span className="text-[10px] text-red-400 font-semibold block">
                        (Dibekukan)
                      </span>
                    )}
                  </TableCell>
                  <TableCell className="text-xs text-muted-foreground max-w-xs truncate">
                    {report.reason}
                  </TableCell>
                  <TableCell>
                    <Badge
                      variant={
                        report.status === "pending"
                          ? "warning"
                          : report.status === "investigating"
                          ? "default"
                          : report.status === "resolved"
                          ? "success"
                          : "secondary"
                      }
                    >
                      {getStatusLabel(report.status)}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-right">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => {
                        setSelectedReport(report);
                        setIsInspectorOpen(true);
                      }}
                      className="flex items-center gap-1 ml-auto text-xs"
                    >
                      <Eye className="w-3.5 h-3.5" />
                      <span>Inspeksi</span>
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </div>

      {/* Modal Detail Inspeksi */}
      <ReportInspectorModal
        report={selectedReport}
        isOpen={isInspectorOpen}
        onClose={() => {
          setIsInspectorOpen(false);
          setSelectedReport(null);
        }}
        onUpdateStatus={handleUpdateStatus}
        onTriggerSuspend={handleTriggerSuspend}
      />

      {/* Modal Konfirmasi Pembekuan */}
      <SuspendUserModal
        isOpen={isSuspendModalOpen}
        onClose={() => {
          setIsSuspendModalOpen(false);
          setSuspendTargetId(null);
        }}
        targetUserId={suspendTargetId || ""}
        targetUserName={suspendTargetName}
        onConfirm={handleConfirmSuspend}
      />
    </div>
  );
}
