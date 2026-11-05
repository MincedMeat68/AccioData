"use client";

import { useEffect, useState } from "react";
import { api } from "./api/client";
import type { Catalog } from "./api/types";

export function useCatalog() {
  const [catalog, setCatalog] = useState<Catalog | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    api
      .catalog()
      .then((c) => !cancelled && setCatalog(c))
      .catch((e: Error) => !cancelled && setError(e.message));
    return () => {
      cancelled = true;
    };
  }, []);

  return { catalog, error };
}
