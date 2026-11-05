"use client";

import { useRouter } from "next/navigation";
import { useCallback, useEffect } from "react";
import { Banner } from "@/components/ui/Banner";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";
import type { Catalog } from "@/lib/api/types";
import { savedPackagesUrl, type SavedAction } from "@/features/packages/savedNotice";
import { builderUrl, type BuilderSource } from "../builderRoutes";
import { usePackageBuilder, type SavedEvent } from "../hooks/usePackageBuilder";
import { PackagePanel } from "./PackagePanel";
import { ServiceCatalogPanel } from "./ServiceCatalogPanel";

interface PackageBuilderProps {
  catalog: Catalog;
  source: BuilderSource;
  /** A save that happened just before this mount, to confirm on screen. */
  justSaved: SavedAction | null;
}

export function PackageBuilder({ catalog, source, justSaved }: PackageBuilderProps) {
  const router = useRouter();
  // Where a save leads:
  // - Existing package (Save Changes / Save as New): back to the package list,
  //   which highlights it (Flow 5).
  // - A brand-new package's first save: stay in the builder (Flow 1), but move
  //   the URL to /?package=<id> so a reload reopens this package rather than
  //   an empty "new" draft.
  const onSaved = useCallback(
    ({ pkg, created, wasEditing }: SavedEvent) => {
      if (wasEditing) router.push(savedPackagesUrl(pkg.id, created ? "created" : "updated"));
      else router.replace(builderUrl.package(pkg.id, "created"), { scroll: false });
    },
    [router],
  );
  const builder = usePackageBuilder(catalog, source, { justSaved, onSaved });

  // Drop the one-time saved flag so a reload doesn't repeat the banner. Same
  // source, so this does not remount the builder.
  const packageId = source.kind === "package" ? source.id : null;
  useEffect(() => {
    if (justSaved && packageId) router.replace(builderUrl.package(packageId), { scroll: false });
  }, [justSaved, packageId, router]);
  const { state, evaluation } = builder;
  const discounts = evaluation?.quote.discounts ?? [];

  return (
    <div className="rounded-xl bg-white p-6 shadow-sm">
      <h1 className="mb-4 text-2xl font-bold">Build Your Screening Package</h1>

      <div className="mb-5 space-y-2" aria-live="polite">
        {state.notice ? (
          <Banner tone={state.notice.tone} title={state.notice.title} onDismiss={builder.dismissNotice}>
            {state.notice.message}
          </Banner>
        ) : (
          discounts.length > 0 && (
            <Banner tone="success" title="Discount applied!">
              {discounts.map((d) => d.label).join(" + ")}
            </Banner>
          )
        )}
      </div>

      {builder.loading ? (
        <p className="py-12 text-center text-slate-500">{source.kind === "latest" ? "Loading your most recent package…" : "Loading package…"}</p>
      ) : (
        <div className="grid gap-6 lg:grid-cols-2">
          <ServiceCatalogPanel
            catalog={catalog}
            rules={builder.rules}
            selected={state.selected}
            notice={state.notice}
            onAdd={builder.add}
            onRemove={builder.remove}
          />
          <div className="lg:sticky lg:top-4 lg:self-start">
            <PackagePanel catalog={catalog} builder={builder} />
          </div>
        </div>
      )}

      {state.confirmation && (
        <ConfirmDialog {...state.confirmation} onConfirm={builder.confirm} onCancel={builder.cancel} />
      )}
    </div>
  );
}
