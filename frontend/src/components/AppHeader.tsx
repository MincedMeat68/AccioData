"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const links = [
  { href: "/", label: "Package Builder" },
  { href: "/packages", label: "Saved Packages" },
];

export function AppHeader() {
  const pathname = usePathname();
  return (
    <header className="bg-blue-900 text-white">
      <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-2 px-4 py-4">
        <Link href="/" className="text-lg font-bold">
          AccioData Background Screening
        </Link>
        <nav className="flex gap-1 text-sm">
          {links.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              aria-current={pathname === link.href ? "page" : undefined}
              className="rounded-md px-3 py-1.5 text-blue-100 hover:bg-blue-800 aria-[current=page]:bg-blue-800 aria-[current=page]:text-white"
            >
              {link.label}
            </Link>
          ))}
        </nav>
      </div>
    </header>
  );
}
