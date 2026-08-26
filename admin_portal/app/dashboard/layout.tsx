"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  Shield,
  LayoutDashboard,
  Flag,
  Users,
  FileText,
  LogOut,
  ShieldAlert,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const router = useRouter();

  const handleLogout = async () => {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push("/login");
    router.refresh();
  };

  const navItems = [
    {
      label: "Ringkasan",
      href: "/dashboard",
      icon: LayoutDashboard,
      active: pathname === "/dashboard",
    },
    {
      label: "Laporan Pengguna",
      href: "/dashboard/reports",
      icon: Flag,
      active: pathname.startsWith("/dashboard/reports"),
    },
    {
      label: "Manajemen Pengguna",
      href: "/dashboard/users",
      icon: Users,
      active: pathname.startsWith("/dashboard/users"),
    },
    {
      label: "Catatan Audit",
      href: "/dashboard/audit-logs",
      icon: FileText,
      active: pathname.startsWith("/dashboard/audit-logs"),
    },
  ];

  return (
    <div className="min-h-screen flex bg-background text-foreground">
      {/* Sidebar Navigasi */}
      <aside className="w-64 border-r border-border/80 bg-card/60 backdrop-blur flex flex-col justify-between shrink-0">
        <div>
          {/* Identitas Brand */}
          <div className="p-6 border-b border-border/80 flex items-center gap-3">
            <div className="p-2 rounded-xl bg-primary/10 border border-primary/20 text-primary">
              <Shield className="w-5 h-5" />
            </div>
            <div>
              <h2 className="font-bold text-base tracking-tight leading-tight">
                MEKAAR 3.0
              </h2>
              <p className="text-[11px] text-muted-foreground font-mono">
                Portal Keselamatan & Moderasi
              </p>
            </div>
          </div>

          {/* Menu Navigasi */}
          <nav className="p-4 space-y-1.5">
            {navItems.map((item) => {
              const Icon = item.icon;
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  prefetch={true}
                  className={`flex items-center gap-3 px-3.5 py-2.5 rounded-lg text-sm font-medium transition-all ${
                    item.active
                      ? "bg-primary text-white shadow-md shadow-primary/20"
                      : "text-muted-foreground hover:text-foreground hover:bg-muted/50"
                  }`}
                >
                  <Icon className="w-4 h-4" />
                  <span>{item.label}</span>
                </Link>
              );
            })}
          </nav>
        </div>

        {/* Footer Sidebar */}
        <div className="p-4 border-t border-border/80 space-y-3">
          <div className="px-3 py-2 rounded-lg bg-muted/40 border border-border/50">
            <div className="text-[10px] uppercase font-semibold text-muted-foreground tracking-wider mb-0.5">
              Status Sistem
            </div>
            <div className="flex items-center gap-2 text-xs text-emerald-400 font-medium">
              <span className="w-2 h-2 rounded-full bg-emerald-500 animate-ping" />
              Basis Data Aktif (E2EE)
            </div>
          </div>

          <Button
            variant="outline"
            size="sm"
            onClick={handleLogout}
            className="w-full flex items-center justify-center gap-2 text-muted-foreground hover:text-destructive hover:border-destructive/40"
          >
            <LogOut className="w-4 h-4" />
            <span>Keluar Sesi</span>
          </Button>
        </div>
      </aside>

      {/* Area Konten Utama */}
      <main className="flex-1 flex flex-col overflow-y-auto">
        <header className="h-16 border-b border-border/80 px-8 flex items-center justify-between bg-card/20 backdrop-blur shrink-0">
          <div className="flex items-center gap-2">
            <span className="text-xs text-muted-foreground font-mono">
              Peran: Administrator Utama
            </span>
          </div>
          <div className="flex items-center gap-3">
            <div className="text-right">
              <div className="text-xs font-semibold">Ketua Tim Keselamatan</div>
              <div className="text-[10px] text-muted-foreground">Otentikasi Supabase SSR</div>
            </div>
            <div className="w-8 h-8 rounded-full bg-primary/20 border border-primary/30 flex items-center justify-center font-bold text-xs text-primary">
              A
            </div>
          </div>
        </header>

        <div className="p-8 flex-1">
          {children}
        </div>
      </main>
    </div>
  );
}
