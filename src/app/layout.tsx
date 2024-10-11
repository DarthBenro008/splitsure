import type { Metadata } from "next";
import localFont from "next/font/local";
import "./globals.css";

const chestor = localFont({
  src: [
    {
      path: "../../public/Chestor-Regular.otf",
      weight: "400",
      style: "normal",
    },
    {
      path: "../../public/Chestor-Medium.otf",
      weight: "500",
      style: "normal",
    },
    {
      path: "../../public/Chestor-Bold.otf",
      weight: "700",
      style: "normal",
    },
  ],
  variable: "--font-sans",
});

export const metadata: Metadata = {
  title: "Splitsure",
  description: "Splitsure",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={`${chestor.variable} font-sans antialiased`}
      >
        {children}
      </body>
    </html>
  );
}
