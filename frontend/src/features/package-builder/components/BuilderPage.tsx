"use client";

import { useSearchParams } from "next/navigation";
import { Banner } from "@/components/ui/Banner";
import { useCatalog } from "@/lib/useCatalog";
import { parseBuilderSource, parseJustSaved, sourceKey } from "../builderRoutes";
import { PackageBuilder } from "./PackageBuilder";

/** Loads the catalog (services + rules), then mounts the builder for whatever the URL asks for. */
export function BuilderPage() {
  const params = useSearchParams();
  const source = parseBuilderSource(params);
  const justSaved = parseJustSaved(params);
  const { catalog, error } = useCatalog();

  if (error) {
    return (
      <Banner tone="error" title="Could not load the service catalog">
        {error}
      </Banner>
    );
  }
  if (!catalog) return <p className="py-12 text-center text-slate-500">Loading services…</p>;

  return <PackageBuilder key={sourceKey(source)} catalog={catalog} source={source} justSaved={justSaved} />;
}
