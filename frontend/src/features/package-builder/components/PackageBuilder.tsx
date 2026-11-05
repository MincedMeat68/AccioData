"use client";

import { useRouter } from "next/navigation";
import { useCallback } from "react";
import { Banner } from "@/components/ui/Banner";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";
import type { Catalog } from "@/lib/api/types";
import { savedPackagesUrl } from "@/features/packages/savedNotice";
import { usePackageBuilder, type SavedEvent } from "../hooks/usePackageBuilder";
import { PackagePanel } from "./PackagePanel";
import { ServiceCatalogPanel } from "./ServiceCatalogPanel";

interface PackageBuilderProps {
  catalog: Catalog;
  packageId: string | null;
}

export function PackageBuilder({ catalog, packageId }: PackageBuilderProps) {
  const router = useRouter();
  // Flow 5: saving an existing package (Save Changes / Save as New) returns
  // to the package list, which highlights it. A brand-new package stays in
  // the builder (Flow 1) so the user can keep refining it.
  const onSaved = useCallback(
    ({ pkg, created, wasEditing }: SavedEvent) => {
      if (wasEditing) router.push(savedPackagesUrl(pkg.id, created ? "created" : "updated"));
    },
    [router],
  );
  const builder = usePackageBuilder(catalog, packageId, onSaved);
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
        <p className="py-12 text-center text-slate-500">Loading your most recent package…</p>
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
