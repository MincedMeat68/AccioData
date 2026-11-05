"use client";

import { useCallback, useEffect, useMemo, useReducer, useState } from "react";
import { api, ApiError } from "@/lib/api/client";
import type { Catalog, SavedPackage, ServiceCode, Template } from "@/lib/api/types";
import { createSelectionRules } from "../rules/selectionRules";
import { builderReducer, initialBuilderState, isDirty } from "../state/builderReducer";
import { useEvaluation } from "./useEvaluation";

/**
 * Wires the pure pieces together: selectionRules decides, the reducer
 * records, the API persists and prices.
 *
 * On mount it opens `packageId` if given (Edit from the list), otherwise the
 * most recently saved package (core requirement 9).
 *
 * `onSaved` runs after a successful save; `wasEditing` is true when the
 * package already existed before this save (Save Changes / Save as New).
 */
export interface SavedEvent {
  pkg: SavedPackage;
  created: boolean;
  wasEditing: boolean;
}

export function usePackageBuilder(
  catalog: Catalog,
  packageId: string | null,
  onSaved?: (event: SavedEvent) => void,
) {
  const rules = useMemo(() => createSelectionRules(catalog), [catalog]);
  const [state, dispatch] = useReducer(builderReducer, initialBuilderState);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const { evaluation, pending, error: pricingError } = useEvaluation(state.selected);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    (packageId ? api.getPackage(packageId) : api.latestPackage())
      .then((pkg) => {
        if (!cancelled && pkg) dispatch({ type: "loaded", pkg });
      })
      .catch((e) => {
        if (cancelled) return;
        dispatch({
          type: "noticeShown",
          notice: { tone: "error", title: "Could not load package", message: (e as Error).message },
        });
      })
      .finally(() => !cancelled && setLoading(false));
    return () => {
      cancelled = true;
    };
  }, [packageId]);

  const add = useCallback(
    (code: ServiceCode) => {
      const decision = rules.decideAdd(state.selected, code);
      switch (decision.kind) {
        case "add":
          return dispatch({ type: "selectionChanged", next: decision.next });
        case "blocked":
          return dispatch({
            type: "noticeShown",
            notice: { tone: "error", title: "Cannot add service", message: decision.message, serviceCode: code },
          });
        case "conflict":
          return dispatch({
            type: "noticeShown",
            notice: { tone: "warning", title: "Service conflict detected", message: decision.message, serviceCode: code },
          });
        case "confirm":
          return dispatch({ type: "confirmationRequested", confirmation: decision.confirmation });
      }
    },
    [rules, state.selected],
  );

  const remove = useCallback(
    (code: ServiceCode) => {
      const decision = rules.decideRemove(state.selected, code);
      if (decision.kind === "remove") dispatch({ type: "selectionChanged", next: decision.next });
      if (decision.kind === "confirm") dispatch({ type: "confirmationRequested", confirmation: decision.confirmation });
    },
    [rules, state.selected],
  );

  const save = useCallback(
    async (options: { asNew?: boolean } = {}) => {
      setSaving(true);
      const input = { name: state.name, service_codes: state.selected };
      const creating = options.asNew || !state.packageId;
      try {
        const pkg = creating ? await api.createPackage(input) : await api.updatePackage(state.packageId!, input);
        dispatch({ type: "saved", pkg, created: creating });
        onSaved?.({ pkg, created: creating, wasEditing: state.packageId !== null });
      } catch (e) {
        const err = e as ApiError;
        dispatch({
          type: "noticeShown",
          notice: {
            tone: "error",
            title: "Package not saved",
            message: err.violations?.length ? err.violations.map((v) => v.message).join(". ") : err.message,
          },
        });
      } finally {
        setSaving(false);
      }
    },
    [state.name, state.selected, state.packageId, onSaved],
  );

  return {
    state,
    rules,
    loading,
    saving,
    evaluation,
    pricingPending: pending,
    pricingError,
    dirty: isDirty(state),
    add,
    remove,
    save,
    confirm: useCallback(() => dispatch({ type: "confirmed" }), []),
    cancel: useCallback(() => dispatch({ type: "cancelled" }), []),
    rename: useCallback((name: string) => dispatch({ type: "renamed", name }), []),
    reset: useCallback(() => dispatch({ type: "reset" }), []),
    applyTemplate: useCallback((template: Template) => dispatch({ type: "templateApplied", template }), []),
    dismissNotice: useCallback(() => dispatch({ type: "noticeDismissed" }), []),
  };
}

export type PackageBuilder = ReturnType<typeof usePackageBuilder>;
