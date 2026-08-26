"use client";

import { ShieldAlert, ShieldCheck } from "lucide-react";
import { Badge } from "@/components/ui/badge";

interface SosActiveBadgeProps {
  isActive: boolean;
}

export function SosActiveBadge({ isActive }: SosActiveBadgeProps) {
  if (isActive) {
    return (
      <Badge variant="destructive" className="flex items-center gap-1.5 animate-pulse font-medium">
        <ShieldAlert className="w-3.5 h-3.5" />
        <span>SOS Aktif (Imunitas Berlaku)</span>
      </Badge>
    );
  }

  return (
    <Badge variant="success" className="flex items-center gap-1.5 font-medium">
      <ShieldCheck className="w-3.5 h-3.5" />
      <span>Normal</span>
    </Badge>
  );
}
