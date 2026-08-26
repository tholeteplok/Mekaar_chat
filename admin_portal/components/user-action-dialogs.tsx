"use client";

import { useState } from "react";
import { Ban, Scale, X, ShieldAlert } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

interface SuspendModalProps {
  isOpen: boolean;
  onClose: () => void;
  targetUserId: string;
  targetUserName?: string;
  isTargetInSos?: boolean;
  onConfirm: (targetUserId: string, reason: string) => Promise<void>;
}

export function SuspendUserModal({
  isOpen,
  onClose,
  targetUserId,
  targetUserName,
  isTargetInSos,
  onConfirm,
}: SuspendModalProps) {
  const [reason, setReason] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!reason.trim()) {
      setError("Alasan pembekuan wajib diisi");
      return;
    }

    try {
      setLoading(true);
      setError(null);
      await onConfirm(targetUserId, reason.trim());
      setReason("");
      onClose();
    } catch (err: any) {
      setError(err?.message || "Gagal membekukan akun");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4 animate-in fade-in duration-200">
      <div className="bg-card border border-border/80 rounded-xl shadow-2xl max-w-md w-full p-6 text-foreground">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2.5 text-destructive font-semibold text-lg">
            <Ban className="w-5 h-5" />
            <h3>Bekukan Akun Pengguna</h3>
          </div>
          <button
            onClick={onClose}
            className="text-muted-foreground hover:text-foreground p-1 rounded-md"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {isTargetInSos && (
          <div className="mb-4 p-3.5 rounded-lg bg-red-950/40 border border-red-500/50 flex items-start gap-2.5 text-xs text-red-300">
            <ShieldAlert className="w-4 h-4 text-red-400 flex-shrink-0 mt-0.5" />
            <div>
              <strong className="font-semibold block">PERINGATAN IMUNITAS SOS AKTIF:</strong>
              Pengguna ini sedang berada dalam Sesi Darurat SOS Aktif. Basis data akan secara otomatis MEMBLOKIR tindakan pembekuan demi keselamatan jiwa target.
            </div>
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="text-xs text-muted-foreground block mb-1">
              Target Pengguna
            </label>
            <div className="p-2.5 rounded-md bg-muted/40 border border-border/50 text-sm font-medium">
              {targetUserName || targetUserId}
            </div>
          </div>

          <div>
            <label className="text-xs text-muted-foreground block mb-1">
              Alasan Pembekuan (Tercatat dalam Catatan Log Audit Permanen) *
            </label>
            <textarea
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder="Contoh: Terbukti melakukan pelanggaran berat pelecehan pada ruang obrolan #xxx"
              rows={3}
              required
              className="w-full rounded-md border border-input bg-background/50 p-2.5 text-sm placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring"
            />
          </div>

          {error && (
            <div className="p-2.5 rounded-md bg-red-950/30 border border-red-500/30 text-xs text-red-400">
              {error}
            </div>
          )}

          <div className="flex items-center justify-end gap-2 pt-2">
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={onClose}
              disabled={loading}
            >
              Batal
            </Button>
            <Button
              type="submit"
              variant="destructive"
              size="sm"
              disabled={loading || isTargetInSos}
            >
              {loading ? "Memproses..." : "Konfirmasi Pembekuan"}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}

interface LegalHoldModalProps {
  isOpen: boolean;
  onClose: () => void;
  targetUserId: string;
  targetUserName?: string;
  currentActive: boolean;
  onConfirm: (targetUserId: string, active: boolean, caseRef: string) => Promise<void>;
}

export function LegalHoldModal({
  isOpen,
  onClose,
  targetUserId,
  targetUserName,
  currentActive,
  onConfirm,
}: LegalHoldModalProps) {
  const [caseRef, setCaseRef] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!isOpen) return null;

  const nextActiveState = !currentActive;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (nextActiveState && !caseRef.trim()) {
      setError("Nomor referensi kasus / perkara hukum wajib diisi");
      return;
    }

    try {
      setLoading(true);
      setError(null);
      await onConfirm(targetUserId, nextActiveState, caseRef.trim());
      setCaseRef("");
      onClose();
    } catch (err: any) {
      setError(err?.message || "Gagal mengubah status penahanan bukti hukum");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4 animate-in fade-in duration-200">
      <div className="bg-card border border-border/80 rounded-xl shadow-2xl max-w-md w-full p-6 text-foreground">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2.5 text-primary font-semibold text-lg">
            <Scale className="w-5 h-5" />
            <h3>
              {nextActiveState ? "Aktifkan Penahanan Bukti Hukum (Legal Hold)" : "Nonaktifkan Penahanan Bukti Hukum"}
            </h3>
          </div>
          <button
            onClick={onClose}
            className="text-muted-foreground hover:text-foreground p-1 rounded-md"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        <p className="text-xs text-muted-foreground mb-4">
          {nextActiveState
            ? "Mengaktifkan Penahanan Bukti Hukum akan membekukan seluruh pembersihan pesan otomatis (pesan menghilang, hapus saat keluar, pembersihan terjadwal) untuk akun ini demi kepatuhan retensi barang bukti hukum."
            : "Menonaktifkan Penahanan Bukti Hukum akan mengembalikan kebijakan retensi pesan dan pembersihan otomatis normal untuk akun ini."}
        </p>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="text-xs text-muted-foreground block mb-1">
              Target Pengguna
            </label>
            <div className="p-2.5 rounded-md bg-muted/40 border border-border/50 text-sm font-medium">
              {targetUserName || targetUserId}
            </div>
          </div>

          <div>
            <label className="text-xs text-muted-foreground block mb-1">
              {nextActiveState
                ? "Referensi Kasus / Nomor Surat Hukum *"
                : "Alasan Pelepasan Penahanan Bukti Hukum"}
            </label>
            <Input
              value={caseRef}
              onChange={(e) => setCaseRef(e.target.value)}
              placeholder={
                nextActiveState
                  ? "Contoh: LP/B/1234/VIII/2026/BARESKRIM"
                  : "Contoh: Proses investigasi perkara telah selesai"
              }
              required={nextActiveState}
            />
          </div>

          {error && (
            <div className="p-2.5 rounded-md bg-red-950/30 border border-red-500/30 text-xs text-red-400">
              {error}
            </div>
          )}

          <div className="flex items-center justify-end gap-2 pt-2">
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={onClose}
              disabled={loading}
            >
              Batal
            </Button>
            <Button
              type="submit"
              variant={nextActiveState ? "default" : "secondary"}
              size="sm"
              disabled={loading}
            >
              {loading
                ? "Menyimpan..."
                : nextActiveState
                ? "Aktifkan Perlindungan Bukti"
                : "Lepas Perlindungan"}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}
