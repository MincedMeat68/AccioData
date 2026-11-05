"use client";

import { useEffect, useState } from "react";
import { api, ApiError } from "@/lib/api/client";
import type { Evaluation, ServiceCode } from "@/lib/api/types";

const DEBOUNCE_MS = 150;

/**
 * Server-side pricing for the current selection. Debounced, and earlier
 * requests are aborted so a slow response can never overwrite a newer one.
 * The previous result stays on screen while the next one loads.
 */
export function useEvaluation(selected: ServiceCode[]) {
  const [evaluation, setEvaluation] = useState<Evaluation | null>(null);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const key = selected.join(",");

  useEffect(() => {
    const controller = new AbortController();
    setPending(true);
    const timer = setTimeout(async () => {
      try {
        const result = await api.evaluate(key ? key.split(",") : [], controller.signal);
        setEvaluation(result);
        setError(null);
      } catch (e) {
        if ((e as Error).name === "AbortError") return;
        setError(e instanceof ApiError ? e.message : "Could not calculate pricing");
      } finally {
        if (!controller.signal.aborted) setPending(false);
      }
    }, DEBOUNCE_MS);

    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [key]);

  return { evaluation, pending, error };
}
