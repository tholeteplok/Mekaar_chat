"use client";

import { useEffect, useState } from "react";
import { Users, Search, Ban, Scale, ShieldAlert, ShieldCheck, RefreshCw, X, Mail } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
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
  SuspendUserModal,
  LegalHoldModal,
} from "@/components/user-action-dialogs";
import { formatDate } from "@/lib/utils";

interface UserProfileItem {
  id: string;
  username: string | null;
  full_name: string | null;
  display_name: string | null;
  email: string | null;
  is_admin: boolean | null;
  is_suspended: boolean | null;
  suspension_reason: string | null;
  legal_hold_active: boolean | null;
  legal_hold_case_ref: string | null;
  created_at: string;
  has_active_sos?: boolean;
}

export default function UsersManagementPage() {
  const [users, setUsers] = useState<UserProfileItem[]>([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [loading, setLoading] = useState(true);

  // Modal Pembekuan Akun
  const [suspendTargetId, setSuspendTargetId] = useState<string | null>(null);
  const [suspendTargetName, setSuspendTargetName] = useState<string>("");
  const [isTargetInSos, setIsTargetInSos] = useState(false);
  const [isSuspendModalOpen, setIsSuspendModalOpen] = useState(false);

  // Modal Penahanan Bukti Hukum (Legal Hold)
  const [legalHoldTargetId, setLegalHoldTargetId] = useState<string | null>(null);
  const [legalHoldTargetName, setLegalHoldTargetName] = useState<string>("");
  const [currentLegalHoldActive, setCurrentLegalHoldActive] = useState(false);
  const [isLegalHoldModalOpen, setIsLegalHoldModalOpen] = useState(false);

  const fetchUsers = async (queryText?: string) => {
    try {
      setLoading(true);
      const supabase = createClient();

      let query = supabase
        .from("profiles")
        .select(`
          id,
          username,
          full_name,
          display_name,
          email,
          is_admin,
          is_suspended,
          suspension_reason,
          legal_hold_active,
          legal_hold_case_ref,
          created_at
        `)
        .order("created_at", { ascending: false })
        .limit(50);

      const text = typeof queryText === "string" ? queryText : searchQuery;
      const clean = text.trim().replace(/^@/, "");

      if (clean) {
        query = query.or(
          `username.ilike.%${clean}%,full_name.ilike.%${clean}%,display_name.ilike.%${clean}%,email.ilike.%${clean}%`
        );
      }

      const { data: profilesData, error } = await query;
      if (error) {
        console.error("[Profiles fetch error]", error);
        throw error;
      }

      // Ambil daftar user yang memiliki sesi SOS aktif
      const { data: activeSosData } = await supabase
        .from("sos_sessions")
        .select("user_id")
        .eq("status", "active");

      const activeSosUserIds = new Set((activeSosData || []).map((s) => s.user_id));

      const enrichedUsers = (profilesData || []).map((u) => ({
        ...u,
        has_active_sos: activeSosUserIds.has(u.id),
      }));

      setUsers(enrichedUsers);
    } catch (err) {
      console.error("[Users fetch error]", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, []);

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    fetchUsers(searchQuery);
  };

  const handleClearSearch = () => {
    setSearchQuery("");
    fetchUsers("");
  };

  const handleConfirmSuspend = async (targetUserId: string, reason: string) => {
    const res = await fetch("/api/admin/suspend", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ targetUserId, reason }),
    });

    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.error || "Gagal membekukan akun");
    }

    alert("Akun berhasil dibekukan dan dicatat ke Catatan Audit.");
    fetchUsers(searchQuery);
  };

  const handleConfirmLegalHold = async (
    targetUserId: string,
    active: boolean,
    caseRef: string
  ) => {
    const res = await fetch("/api/admin/legal-hold", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ targetUserId, active, caseRef }),
    });

    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.error || "Gagal mengubah status penahanan bukti hukum");
    }

    alert(
      active
        ? "Status Penahanan Bukti Hukum berhasil diaktifkan. Pembersihan pesan dibekukan."
        : "Status Penahanan Bukti Hukum dinonaktifkan."
    );
    fetchUsers(searchQuery);
  };

  return (
    <div className="space-y-6">
      {/* Judul & Deskripsi */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Manajemen Pengguna & Kepatuhan</h1>
          <p className="text-sm text-muted-foreground mt-1">
            Cari akun pengguna, kendalikan status pembekuan akun, dan kelola penahanan retensi bukti hukum (Legal Hold).
          </p>
        </div>

        <Button
          variant="outline"
          size="sm"
          onClick={() => fetchUsers(searchQuery)}
          disabled={loading}
          className="flex items-center gap-1.5 self-start md:self-auto"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? "animate-spin" : ""}`} />
          <span>Muat Ulang</span>
        </Button>
      </div>

      {/* Bilah Pencarian */}
      <form onSubmit={handleSearchSubmit} className="flex gap-2">
        <div className="relative flex-1 max-w-md">
          <Search className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
          <Input
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Cari surel, nama pengguna, nama lengkap, atau panggilan..."
            className="pl-9 pr-8"
          />
          {searchQuery && (
            <button
              type="button"
              onClick={handleClearSearch}
              className="absolute right-2.5 top-2.5 text-muted-foreground hover:text-foreground p-0.5"
            >
              <X className="w-4 h-4" />
            </button>
          )}
        </div>
        <Button type="submit" size="sm" disabled={loading}>
          Cari
        </Button>
      </form>

      {/* Tabel Pengguna */}
      <div className="rounded-xl border border-border/80 bg-card overflow-hidden">
        {loading ? (
          <div className="p-8 text-center text-sm text-muted-foreground">
            Memuat daftar pengguna...
          </div>
        ) : users.length === 0 ? (
          <div className="p-8 text-center text-sm text-muted-foreground">
            Pengguna tidak ditemukan{searchQuery ? ` untuk kata kunci "${searchQuery}"` : ""}.
          </div>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Pengguna & Identitas</TableHead>
                <TableHead>Surel / UID</TableHead>
                <TableHead>Status Akun</TableHead>
                <TableHead>Penahanan Bukti (Legal Hold)</TableHead>
                <TableHead>Status Darurat SOS</TableHead>
                <TableHead className="text-right">Tindakan</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {users.map((user) => (
                <TableRow key={user.id}>
                  <TableCell>
                    <div className="font-medium text-foreground flex items-center gap-2">
                      <span>{user.display_name || user.full_name || user.username || "Pengguna MEKAAR"}</span>
                      {user.is_admin && (
                        <Badge variant="default" className="text-[10px] py-0">
                          ADMINISTRATOR
                        </Badge>
                      )}
                    </div>
                    <div className="text-xs text-muted-foreground font-mono">
                      @{user.username || "tanpa-username"} {user.full_name && user.display_name && `(${user.full_name})`}
                    </div>
                  </TableCell>

                  <TableCell className="text-xs">
                    <div className="text-foreground font-medium flex items-center gap-1.5">
                      <Mail className="w-3.5 h-3.5 text-muted-foreground" />
                      <span>{user.email || "-"}</span>
                    </div>
                    <div className="text-[10px] font-mono text-muted-foreground/60 mt-0.5">
                      {user.id}
                    </div>
                  </TableCell>

                  <TableCell>
                    {user.is_suspended ? (
                      <div>
                        <Badge variant="destructive">DIBEKUKAN</Badge>
                        {user.suspension_reason && (
                          <p className="text-[11px] text-red-400 mt-1 max-w-xs truncate">
                            {user.suspension_reason}
                          </p>
                        )}
                      </div>
                    ) : (
                      <Badge variant="success">AKTIF</Badge>
                    )}
                  </TableCell>

                  <TableCell>
                    {user.legal_hold_active ? (
                      <div>
                        <Badge variant="warning" className="flex items-center gap-1 w-fit">
                          <Scale className="w-3 h-3" />
                          <span>AKTIF</span>
                        </Badge>
                        {user.legal_hold_case_ref && (
                          <p className="text-[11px] font-mono text-amber-400/90 mt-1">
                            Ref: {user.legal_hold_case_ref}
                          </p>
                        )}
                      </div>
                    ) : (
                      <span className="text-xs text-muted-foreground">-</span>
                    )}
                  </TableCell>

                  <TableCell>
                    {user.has_active_sos ? (
                      <Badge variant="destructive" className="animate-pulse flex items-center gap-1 w-fit">
                        <ShieldAlert className="w-3 h-3" />
                        <span>SOS AKTIF</span>
                      </Badge>
                    ) : (
                      <span className="text-xs text-muted-foreground">Normal</span>
                    )}
                  </TableCell>

                  <TableCell className="text-right">
                    <div className="flex items-center justify-end gap-2">
                      {/* Tombol Legal Hold */}
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => {
                          setLegalHoldTargetId(user.id);
                          setLegalHoldTargetName(user.display_name || user.full_name || user.username || user.id);
                          setCurrentLegalHoldActive(user.legal_hold_active === true);
                          setIsLegalHoldModalOpen(true);
                        }}
                        className="text-xs"
                      >
                        <Scale className="w-3.5 h-3.5 mr-1" />
                        <span>Legal Hold</span>
                      </Button>

                      {/* Tombol Bekukan */}
                      {!user.is_suspended ? (
                        <Button
                          variant="destructive"
                          size="sm"
                          onClick={() => {
                            setSuspendTargetId(user.id);
                            setSuspendTargetName(user.display_name || user.full_name || user.username || user.id);
                            setIsTargetInSos(user.has_active_sos === true);
                            setIsSuspendModalOpen(true);
                          }}
                          className="text-xs"
                        >
                          <Ban className="w-3.5 h-3.5 mr-1" />
                          <span>Bekukan</span>
                        </Button>
                      ) : (
                        <Badge variant="secondary" className="text-xs">
                          Terkunci
                        </Badge>
                      )}
                    </div>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </div>

      {/* Modal Pembekuan Akun */}
      <SuspendUserModal
        isOpen={isSuspendModalOpen}
        onClose={() => {
          setIsSuspendModalOpen(false);
          setSuspendTargetId(null);
        }}
        targetUserId={suspendTargetId || ""}
        targetUserName={suspendTargetName}
        isTargetInSos={isTargetInSos}
        onConfirm={handleConfirmSuspend}
      />

      {/* Modal Legal Hold */}
      <LegalHoldModal
        isOpen={isLegalHoldModalOpen}
        onClose={() => {
          setIsLegalHoldModalOpen(false);
          setLegalHoldTargetId(null);
        }}
        targetUserId={legalHoldTargetId || ""}
        targetUserName={legalHoldTargetName}
        currentActive={currentLegalHoldActive}
        onConfirm={handleConfirmLegalHold}
      />
    </div>
  );
}
