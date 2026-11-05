"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { Banner, type BannerTone } from "@/components/ui/Banner";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";
import { api } from "@/lib/api/client";
import type { SavedPackage } from "@/lib/api/types";
import { formatCents, formatDateTime, pluralize } from "@/lib/format";
import { readSavedNotice } from "./savedNotice";

type Message = { tone: BannerTone; title: string } | null;
type Highlight = { id: string; badge: string } | null;

/** Saved packages (stretch goal): list, edit, duplicate, delete. */
export function PackageList() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [packages, setPackages] = useState<SavedPackage[] | null>(null);
  const [message, setMessage] = useState<Message>(null);
  const [pendingDelete, setPendingDelete] = useState<SavedPackage | null>(null);
  const [highlight, setHighlight] = useState<Highlight>(null);

  const load = useCallback(async () => {
    try {
      setPackages(await api.listPackages());
    } catch (e) {
      setMessage({ tone: "error", title: (e as Error).message });
      setPackages([]);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  // Arriving from the builder after a save (Flow 5): confirm it and highlight
  // the package, then drop the query so a refresh doesn't repeat the banner.
  useEffect(() => {
    const saved = readSavedNotice(searchParams);
    if (!saved || !packages) return;
    const pkg = packages.find((p) => p.id === saved.id);
    if (pkg) {
      setMessage({ tone: "success", title: `Package saved successfully! "${pkg.name}" has been ${saved.action}.` });
      setHighlight({ id: pkg.id, badge: saved.action === "created" ? "Just created" : "Just updated" });
    }
    router.replace("/packages", { scroll: false });
  }, [searchParams, packages, router]);

  async function duplicate(pkg: SavedPackage) {
    try {
      const copy = await api.duplicatePackage(pkg.id);
      setHighlight({ id: copy.id, badge: "Just created" });
      setMessage({ tone: "success", title: `Created "${copy.name}"` });
      await load();
    } catch (e) {
      setMessage({ tone: "error", title: (e as Error).message });
    }
  }

  async function confirmDelete() {
    const pkg = pendingDelete!;
    setPendingDelete(null);
    try {
      await api.deletePackage(pkg.id);
      setMessage({ tone: "success", title: `Deleted "${pkg.name}"` });
      await load();
    } catch (e) {
      setMessage({ tone: "error", title: (e as Error).message });
    }
  }

  const totalValue = packages?.reduce((sum, p) => sum + p.quote.total_cents, 0) ?? 0;

  return (
    <div className="rounded-xl bg-white p-6 shadow-sm">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-bold">Saved Packages</h1>
        <Link href="/" className="rounded-md bg-blue-900 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-800">
          + Create New Package
        </Link>
      </div>

      {message && (
        <div className="mb-4">
          <Banner tone={message.tone} title={message.title} onDismiss={() => setMessage(null)} />
        </div>
      )}

      {packages === null ? (
        <p className="py-12 text-center text-slate-500">Loading packages…</p>
      ) : packages.length === 0 ? (
        <div className="py-12 text-center text-slate-500">
          <p className="font-medium">No saved packages yet</p>
          <Link href="/" className="text-sm text-blue-700 underline">
            Build your first package
          </Link>
        </div>
      ) : (
        <>
          <ul className="grid gap-4 md:grid-cols-2">
            {packages.map((pkg) => (
              <PackageCard
                key={pkg.id}
                pkg={pkg}
                badge={pkg.id === highlight?.id ? highlight.badge : null}
                onDuplicate={() => duplicate(pkg)}
                onDelete={() => setPendingDelete(pkg)}
              />
            ))}
          </ul>
          <p className="mt-4 text-xs text-slate-500">
            Showing {pluralize(packages.length, "package")} · Total value {formatCents(totalValue)}
          </p>
        </>
      )}

      {pendingDelete && (
        <ConfirmDialog
          tone="danger"
          title={`Delete "${pendingDelete.name}"?`}
          message="This permanently deletes the saved package. It cannot be undone."
          confirmLabel="Delete package"
          cancelLabel="Cancel - keep it"
          onConfirm={confirmDelete}
          onCancel={() => setPendingDelete(null)}
        />
      )}
    </div>
  );
}

interface PackageCardProps {
  pkg: SavedPackage;
  /** "Just created" / "Just updated" - set when this card was just saved. */
  badge: string | null;
  onDuplicate: () => void;
  onDelete: () => void;
}

function PackageCard({ pkg, badge, onDuplicate, onDelete }: PackageCardProps) {
  const { quote } = pkg;
  return (
    <li
      className={`flex flex-col rounded-lg border p-4 ${badge ? "border-blue-500 bg-white ring-2 ring-blue-100" : "border-slate-200 bg-slate-50"}`}
    >
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0">
          {badge && (
            <span className="mb-1 inline-block rounded-full bg-blue-100 px-2.5 py-0.5 text-[11px] font-semibold tracking-wide text-blue-800 uppercase">
              {badge}
            </span>
          )}
          <h2 className="truncate text-lg font-semibold">{pkg.name}</h2>
          <p className="text-xs text-slate-500">Updated {formatDateTime(pkg.updated_at)}</p>
        </div>
        <div className="flex shrink-0 gap-1.5">
          <Link
            href={`/?package=${encodeURIComponent(pkg.id)}`}
            className="rounded-md bg-blue-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-blue-700"
          >
            Edit
          </Link>
          <button
            type="button"
            onClick={onDuplicate}
            className="rounded-md border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium hover:bg-slate-100"
          >
            Duplicate
          </button>
          <button
            type="button"
            onClick={onDelete}
            aria-label={`Delete ${pkg.name}`}
            className="rounded-md border border-red-200 bg-white px-3 py-1.5 text-xs font-medium text-red-600 hover:bg-red-50"
          >
            Delete
          </button>
        </div>
      </div>

      <p className="mt-3 text-xs font-semibold text-slate-700">{pluralize(quote.service_count, "Service")} Included:</p>
      <p className="text-xs text-slate-600">{quote.line_items.map((li) => li.name).join(" · ")}</p>

      {pkg.violations.length > 0 && (
        <p className="mt-2 rounded bg-amber-50 px-2 py-1 text-xs text-amber-800">⚠ {pkg.violations[0].message}</p>
      )}

      <div className="mt-auto flex items-end justify-between border-t border-slate-200 pt-3 text-xs text-slate-600">
        <span>
          Subtotal {formatCents(quote.subtotal_cents)}
          {quote.discounts.length > 0
            ? ` · Discounts −${formatCents(quote.discount_total_cents)}`
            : " · No discounts applied"}
        </span>
        <span className="text-lg font-bold text-blue-900">{formatCents(quote.total_cents)}</span>
      </div>
    </li>
  );
}
