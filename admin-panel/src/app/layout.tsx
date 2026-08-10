import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "RepuestosYa - Panel Admin",
  description: "Panel de administración de RepuestosYa",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="es">
      <body className="bg-dark text-white min-h-screen">
        {children}
      </body>
    </html>
  );
}
