"use client";

import { useSearchParams } from "next/navigation";
import { Banner } from "@/components/ui/Banner";
import { useCatalog } from "@/lib/useCatalog";
import { PackageBuilder } from "./PackageBuilder";

/** Loads the catalog (services + rules), then mounts the builder for ?package=<id> or the latest package. */
export function BuilderPage() {
  const packageId = useSearchParams().get("package");
  const { catalog, error } = useCatalog();

  if (error) {
    return (
      <Banner tone="error" title="Could not load the service catalog">
        {error}
      </Banner>
    );
  }
  if (!catalog) return <p className="py-12 text-center text-slate-500">Loading services…</p>;

  return <PackageBuilder key={packageId ?? "latest"} catalog={catalog} packageId={packageId} />;
}
