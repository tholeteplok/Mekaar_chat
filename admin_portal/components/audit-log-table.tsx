"use client";

import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { formatDate } from "@/lib/utils";

export interface AuditLogItem {
  id: string;
  admin_id: string;
  action_type: "SUSPEND" | "UNSUSPEND" | "ENABLE_LEGAL_HOLD" | "DISABLE_LEGAL_HOLD" | "PURGE";
  target_user_id: string;
  reason: string;
  ip_address: string | null;
  metadata: any;
  created_at: string;
  admin?: {
    full_name: string | null;
  } | null;
  target?: {
    full_name: string | null;
  } | null;
}

interface AuditLogTableProps {
  logs: AuditLogItem[];
  loading?: boolean;
}

export function AuditLogTable({ logs, loading }: AuditLogTableProps) {
  const actionColorMap: Record<string, "default" | "destructive" | "warning" | "success" | "secondary"> = {
    SUSPEND: "destructive",
    UNSUSPEND: "success",
    ENABLE_LEGAL_HOLD: "default",
    DISABLE_LEGAL_HOLD: "secondary",
    PURGE: "warning",
  };

  const getActionLabel = (action: string) => {
    switch (action) {
      case "SUSPEND":
        return "PEMBEKUAN";
      case "UNSUSPEND":
        return "LEPAS BEKU";
      case "ENABLE_LEGAL_HOLD":
        return "AKTIFKAN LEGAL HOLD";
      case "DISABLE_LEGAL_HOLD":
        return "NONAKTIFKAN LEGAL HOLD";
      case "PURGE":
        return "PEMBERSIHAN DATA";
      default:
        return action;
    }
  };

  if (loading) {
    return (
      <div className="p-8 text-center text-sm text-muted-foreground">
        Memuat catatan log audit...
      </div>
    );
  }

  if (logs.length === 0) {
    return (
      <div className="p-8 text-center text-sm text-muted-foreground">
        Belum ada riwayat tindakan administrasi yang tercatat.
      </div>
    );
  }

  return (
    <div className="rounded-lg border border-border/80 bg-card overflow-hidden">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead className="w-[180px]">Waktu Tindakan</TableHead>
            <TableHead>Tipe Tindakan</TableHead>
            <TableHead>Admin Eksekutor</TableHead>
            <TableHead>Target Pengguna</TableHead>
            <TableHead>Alasan / Ref. Perkara</TableHead>
            <TableHead className="w-[120px]">IP / Metadata</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {logs.map((log) => (
            <TableRow key={log.id}>
              <TableCell className="text-xs font-mono text-muted-foreground whitespace-nowrap">
                {formatDate(log.created_at)}
              </TableCell>
              <TableCell>
                <Badge variant={actionColorMap[log.action_type] || "default"}>
                  {getActionLabel(log.action_type)}
                </Badge>
              </TableCell>
              <TableCell className="text-sm">
                <div className="font-medium text-foreground">
                  {log.admin?.full_name || "Admin"}
                </div>
                <div className="text-[11px] font-mono text-muted-foreground">
                  {log.admin_id.slice(0, 8)}...
                </div>
              </TableCell>
              <TableCell className="text-sm">
                <div className="font-medium text-foreground">
                  {log.target?.full_name || "Pengguna"}
                </div>
                <div className="text-[11px] font-mono text-muted-foreground">
                  {log.target_user_id.slice(0, 8)}...
                </div>
              </TableCell>
              <TableCell className="text-xs text-foreground max-w-md break-words">
                {log.reason}
              </TableCell>
              <TableCell className="text-[11px] font-mono text-muted-foreground">
                {log.ip_address || "Internal/Web"}
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
