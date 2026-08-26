import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet: Array<{ name: string; value: string; options?: any }>) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const pathname = request.nextUrl.pathname;
  const isAuthPage = pathname.startsWith("/login");
  const isDashboardPage = pathname.startsWith("/dashboard");
  const isApiAdminPage = pathname.startsWith("/api/admin");

  // 1. Verifikasi User ke Server Auth menggunakan getUser()
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !user) {
    // Bersihkan admin cookie jika sesi auth tidak valid
    response.cookies.delete("mekaar_admin_cached");
    if (isDashboardPage || isApiAdminPage) {
      return NextResponse.redirect(new URL("/login", request.url));
    }
    return response;
  }

  // 2. Cek Cache Role Admin dari Cookie untuk Navigasi Cepat (<50ms)
  const cachedAdmin = request.cookies.get("mekaar_admin_cached")?.value;
  let isAdmin = cachedAdmin === user.id;

  if (!isAdmin) {
    // Query Status Admin ke public.profiles hanya jika belum ada di cache
    const { data: profile } = await supabase
      .from("profiles")
      .select("is_admin")
      .eq("id", user.id)
      .single();

    isAdmin = profile?.is_admin === true;

    if (isAdmin) {
      // Simpan status admin terverifikasi di cookie sesi
      response.cookies.set("mekaar_admin_cached", user.id, {
        httpOnly: true,
        secure: process.env.NODE_ENV === "production",
        sameSite: "lax",
        maxAge: 60 * 60 * 2, // 2 jam
      });
    }
  }

  if (!isAdmin) {
    response.cookies.delete("mekaar_admin_cached");
    if (isDashboardPage || isApiAdminPage) {
      return NextResponse.redirect(new URL("/login?error=unauthorized", request.url));
    }
  } else if (isAuthPage) {
    return NextResponse.redirect(new URL("/dashboard", request.url));
  }

  return response;
}

export const config = {
  matcher: ["/dashboard/:path*", "/api/admin/:path*", "/login"],
};
