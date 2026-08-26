"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import {
  ShieldAlert,
  Flag,
  Users,
  Scale,
  ArrowUpRight,
  Clock,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Card, CardHeader, CardTitle, CardContent, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { SosActiveBadge } from "@/components/sos-active-badge";
import { formatDate } from "@/lib/utils";

interface DashboardMetrics {
  pendingReports: number;
  activeSosSessions: number;
  suspendedUsers: number;
  activeLegalHolds: number;
}

interface ActiveSosItem {
  id: string;
  user_id: string;
  status: string;
  trigger_type: string;
  created_at: string;
  user?: {
    full_name: string | null;
    username: string | null;
    email: string | null;
  } | null;
}

export default function DashboardOverviewPage() {
  const [metrics, setMetrics] = useState<DashboardMetrics>({
    pendingReports: 0,
    activeSosSessions: 0,
    suspendedUsers: 0,
    activeLegalHolds: 0,
  });
  const [activeSosList, setActiveSosList] = useState<ActiveSosItem[]>([]);
  const [recentReports, setRecentReports] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchDashboardData = async () => {
    try {
      setLoading(true);
      const supabase = createClient();

      // 1. Ambil jumlah laporan menunggu
      const { count: pendingCount } = await supabase
        .from("user_reports")
        .select("*", { count: "exact", head: true })
        .eq("status", "pending");

      // 2. Ambil sesi SOS aktif
      const { data: sosData, count: sosCount } = await supabase
        .from("sos_sessions")
        .select(`
          id,
          user_id,
          status,
          trigger_type,
          created_at,
          user:profiles!sos_sessions_user_id_fkey(full_name, username, email)
        `)
        .eq("status", "active")
        .order("created_at", { ascending: false });

      // 3. Ambil jumlah pengguna dibekukan
      const { count: suspendedCount } = await supabase
        .from("profiles")
        .select("*", { count: "exact", head: true })
        .eq("is_suspended", true);

      // 4. Ambil jumlah kasus penahanan hukum aktif
      const { count: legalHoldCount } = await supabase
        .from("profiles")
        .select("*", { count: "exact", head: true })
        .eq("legal_hold_active", true);

      // 5. Ambil 5 laporan terbaru
      const { data: reportsData } = await supabase
        .from("user_reports")
        .select(`
          id,
          category,
          reason,
          status,
          created_at,
          reporter:profiles!user_reports_reporter_id_fkey(full_name, username),
          reported:profiles!user_reports_reported_user_id_fkey(full_name, username)
        `)
        .order("created_at", { ascending: false })
        .limit(5);

      setMetrics({
        pendingReports: pendingCount || 0,
        activeSosSessions: sosCount || 0,
        suspendedUsers: suspendedCount || 0,
        activeLegalHolds: legalHoldCount || 0,
      });

      setActiveSosList((sosData as any) || []);
      setRecentReports(reportsData || []);
    } catch (err) {
      console.error("[DashboardOverview error]", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDashboardData();

    // Berlangganan ke Realtime SOS Sessions & Reports
    const supabase = createClient();
    const sosChannel = supabase
      .channel("admin-dashboard-realtime")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "sos_sessions" },
        () => fetchDashboardData()
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "user_reports" },
        () => fetchDashboardData()
      )
      .subscribe();

    return () => {
      supabase.removeChannel(sosChannel);
    };
  }, []);

  const getCategoryLabel = (category: string) => {
    switch (category) {
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
    <div className="space-y-8">
      {/* Judul Halaman */}
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Ringkasan Sistem & Keamanan</h1>
        <p className="text-sm text-muted-foreground mt-1">
          Pantau status darurat SOS, antrean laporan pengguna, dan penahanan retensi hukum secara langsung.
        </p>
      </div>

      {/* Kartu Metrik Ringkasan */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Metrik 1: Laporan Menunggu */}
        <Card className="border-border/80 bg-card/60">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
              Antrean Laporan Menunggu
            </CardTitle>
            <Flag className="w-4 h-4 text-amber-400" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-amber-400">
              {metrics.pendingReports}
            </div>
            <p className="text-xs text-muted-foreground mt-1">
              Perlu ditinjau tim moderasi
            </p>
          </CardContent>
        </Card>

        {/* Metrik 2: Sesi SOS Aktif */}
        <Card className="border-red-500/30 bg-red-950/10">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-xs font-semibold text-red-400 uppercase tracking-wider">
              Sesi SOS Darurat Aktif
            </CardTitle>
            <ShieldAlert className="w-4 h-4 text-red-400 animate-pulse" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-red-400">
              {metrics.activeSosSessions}
            </div>
            <p className="text-xs text-muted-foreground mt-1">
              Mendapat proteksi imunitas pembekuan
            </p>
          </CardContent>
        </Card>

        {/* Metrik 3: Pengguna Dibekukan */}
        <Card className="border-border/80 bg-card/60">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
              Pengguna Dibekukan
            </CardTitle>
            <Users className="w-4 h-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-foreground">
              {metrics.suspendedUsers}
            </div>
            <p className="text-xs text-muted-foreground mt-1">
              Akun terkunci (Akses Ditolak)
            </p>
          </CardContent>
        </Card>

        {/* Metrik 4: Kasus Penahanan Hukum */}
        <Card className="border-border/80 bg-card/60">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
              Kasus Penahanan Hukum (Legal Hold)
            </CardTitle>
            <Scale className="w-4 h-4 text-primary" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-primary">
              {metrics.activeLegalHolds}
            </div>
            <p className="text-xs text-muted-foreground mt-1">
              Pembersihan pesan dibekukan
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Pemantauan Langsung Sesi Darurat SOS */}
      <Card className="border-red-500/30 bg-card/60 overflow-hidden">
        <CardHeader className="border-b border-border/60 bg-red-950/20 flex flex-row items-center justify-between">
          <div className="flex items-center gap-2">
            <ShieldAlert className="w-5 h-5 text-red-400 animate-pulse" />
            <div>
              <CardTitle className="text-base text-red-400">
                Pemantauan Sesi Darurat SOS Aktif (Imunitas Langsung)
              </CardTitle>
              <CardDescription className="text-xs text-muted-foreground">
                Pengguna di bawah ini memiliki status imunitas keselamatan basis data — tindakan pembekuan akun diblokir secara otomatis.
              </CardDescription>
            </div>
          </div>
          <Badge variant="destructive" className="animate-pulse">
            PEMANTAUAN LANGSUNG
          </Badge>
        </CardHeader>
        <CardContent className="p-0">
          {activeSosList.length === 0 ? (
            <div className="p-6 text-center text-xs text-muted-foreground">
              🟢 Tidak ada sesi darurat SOS yang sedang aktif saat ini.
            </div>
          ) : (
            <div className="divide-y divide-border/60">
              {activeSosList.map((sos) => (
                <div
                  key={sos.id}
                  className="p-4 flex items-center justify-between hover:bg-muted/20 transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="p-2 rounded-lg bg-red-500/20 text-red-400">
                      <ShieldAlert className="w-4 h-4" />
                    </div>
                    <div>
                      <div className="font-semibold text-sm text-foreground">
                        {sos.user?.full_name || (sos.user?.username ? `@${sos.user.username}` : "Nama Pengguna Tidak Diketahui")}
                      </div>
                      <div className="text-xs text-muted-foreground font-mono">
                        UID: {sos.user_id} • {sos.user?.email || "-"}
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-4">
                    <div className="text-right text-xs">
                      <div className="text-muted-foreground font-mono flex items-center gap-1">
                        <Clock className="w-3 h-3" />
                        {formatDate(sos.created_at)}
                      </div>
                      <span className="text-[11px] text-amber-400 uppercase font-semibold">
                        Pemicu: {sos.trigger_type === "manual" ? "Manual" : sos.trigger_type || "Manual"}
                      </span>
                    </div>
                    <SosActiveBadge isActive={true} />
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Ringkasan Laporan Pengguna Terbaru */}
      <Card className="border-border/80 bg-card/60">
        <CardHeader className="flex flex-row items-center justify-between">
          <div>
            <CardTitle className="text-base">Laporan Pengguna Terbaru</CardTitle>
            <CardDescription className="text-xs">
              Antrean pelaporan masuk dari anggota ruang obrolan terenkripsi E2EE.
            </CardDescription>
          </div>
          <Link
            href="/dashboard/reports"
            prefetch={true}
            className="inline-flex items-center justify-center rounded-md text-xs font-medium border border-input bg-background hover:bg-accent hover:text-accent-foreground h-8 px-3 transition-colors gap-1"
          >
            <span>Buka Semua Laporan</span>
            <ArrowUpRight className="w-3.5 h-3.5" />
          </Link>
        </CardHeader>
        <CardContent className="p-0">
          {recentReports.length === 0 ? (
            <div className="p-6 text-center text-xs text-muted-foreground">
              Belum ada laporan pengguna yang masuk.
            </div>
          ) : (
            <div className="divide-y divide-border/60">
              {recentReports.map((report) => (
                <div
                  key={report.id}
                  className="p-4 flex items-center justify-between hover:bg-muted/20 transition-colors text-sm"
                >
                  <div className="space-y-1">
                    <div className="flex items-center gap-2">
                      <Badge variant={report.category === "fake_sos" ? "destructive" : "warning"}>
                        {getCategoryLabel(report.category)}
                      </Badge>
                      <span className="font-medium text-foreground">
                        {report.reported?.full_name || (report.reported?.username ? `@${report.reported.username}` : "Pengguna Terlapor")}
                      </span>
                      <span className="text-xs text-muted-foreground">
                        dilaporkan oleh {report.reporter?.full_name || (report.reporter?.username ? `@${report.reporter.username}` : "Pelapor")}
                      </span>
                    </div>
                    <p className="text-xs text-muted-foreground line-clamp-1">
                      {report.reason}
                    </p>
                  </div>

                  <div className="text-right text-xs">
                    <span className="text-muted-foreground block mb-1">
                      {formatDate(report.created_at)}
                    </span>
                    <Badge variant={report.status === "pending" ? "warning" : "default"}>
                      {getStatusLabel(report.status)}
                    </Badge>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
