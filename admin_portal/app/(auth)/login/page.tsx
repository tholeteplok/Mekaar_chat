"use client";

import { Suspense, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Shield, Lock, Mail, AlertCircle, ArrowRight } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";

function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const errorParam = searchParams.get("error");

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(
    errorParam === "unauthorized"
      ? "Akun Anda tidak memiliki hak akses Administrator."
      : null
  );

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const supabase = createClient();
      const { data, error: signInError } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (signInError) {
        throw signInError;
      }

      if (data?.user) {
        // Cek status profiles.is_admin
        const { data: profile, error: profileError } = await supabase
          .from("profiles")
          .select("is_admin")
          .eq("id", data.user.id)
          .single();

        if (profileError || !profile?.is_admin) {
          await supabase.auth.signOut();
          setError("Akses ditolak: Akun Anda terautentikasi tetapi bukan Administrator.");
          return;
        }

        router.push("/dashboard");
        router.refresh();
      }
    } catch (err: any) {
      setError(err?.message || "Gagal masuk ke sistem.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Card className="border-border/80 shadow-2xl">
      <CardHeader className="space-y-1 pb-4">
        <CardTitle className="text-xl text-center">Masuk ke Portal</CardTitle>
        <CardDescription className="text-center text-xs">
          Hanya administrator resmi MEKAAR yang diizinkan mengakses panel ini.
        </CardDescription>
      </CardHeader>
      <CardContent>
        {error && (
          <div className="mb-4 p-3 rounded-lg bg-red-950/40 border border-red-500/40 text-red-400 text-xs flex items-start gap-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5" />
            <span>{error}</span>
          </div>
        )}

        <form onSubmit={handleLogin} className="space-y-4">
          <div className="space-y-1.5">
            <label className="text-xs font-medium text-muted-foreground">
              Surel Administrator
            </label>
            <div className="relative">
              <Mail className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
              <Input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@mekaar.internal"
                required
                className="pl-9"
              />
            </div>
          </div>

          <div className="space-y-1.5">
            <label className="text-xs font-medium text-muted-foreground">
              Kata Sandi
            </label>
            <div className="relative">
              <Lock className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
              <Input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                required
                className="pl-9"
              />
            </div>
          </div>

          <Button
            type="submit"
            className="w-full mt-2"
            disabled={loading}
          >
            {loading ? (
              "Memverifikasi..."
            ) : (
              <span className="flex items-center justify-center gap-2">
                Masuk Sekarang <ArrowRight className="w-4 h-4" />
              </span>
            )}
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}

export default function LoginPage() {
  return (
    <div className="min-h-screen flex items-center justify-center p-4 bg-gradient-to-b from-background via-card/50 to-background">
      <div className="max-w-md w-full">
        <div className="text-center mb-8">
          <div className="inline-flex p-3 rounded-2xl bg-primary/10 border border-primary/20 text-primary mb-3 shadow-inner">
            <Shield className="w-8 h-8" />
          </div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">
            MEKAAR 3.0
          </h1>
          <p className="text-sm text-muted-foreground mt-1">
            Portal Moderasi & Keselamatan Admin
          </p>
        </div>

        <Suspense fallback={<div className="p-8 text-center text-sm text-muted-foreground">Memuat formulir masuk...</div>}>
          <LoginForm />
        </Suspense>

        <p className="text-center text-[11px] text-muted-foreground/60 mt-6">
          Sistem Terenkripsi & Diawasi oleh Catatan Audit Permanen.
        </p>
      </div>
    </div>
  );
}
