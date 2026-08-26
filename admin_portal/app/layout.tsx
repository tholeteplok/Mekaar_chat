import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "MEKAAR 3.0 — Portal Moderasi & Keselamatan Admin",
  description: "Portal internal untuk Keselamatan, Moderasi, dan Kepatuhan Hukum MEKAAR.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="id" className="dark">
      <body className="min-h-screen bg-background font-sans antialiased text-foreground">
        {children}
      </body>
    </html>
  );
}
