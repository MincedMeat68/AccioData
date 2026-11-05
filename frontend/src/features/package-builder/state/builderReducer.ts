/**
 * Builder state machine. Pure: rule decisions are made by selectionRules and
 * passed in as actions, so the reducer only records what happened.
 */
import type { SavedPackage, ServiceCode, Template } from "@/lib/api/types";
import type { Confirmation } from "../rules/selectionRules";

export interface Notice {
  tone: "error" | "warning" | "success" | "info";
  title: string;
  message?: string;
  /** Service card to highlight alongside the notice. */
  serviceCode?: ServiceCode;
}

export interface BuilderState {
  packageId: string | null;
  name: string;
  selected: ServiceCode[];
  /** Last saved/loaded name + selection, to detect unsaved changes. */
  baseline: { name: string; selected: ServiceCode[] } | null;
  notice: Notice | null;
  confirmation: Confirmation | null;
}

export type BuilderAction =
  | { type: "loaded"; pkg: SavedPackage }
  | { type: "saved"; pkg: SavedPackage; created: boolean }
  | { type: "reset" }
  | { type: "templateApplied"; template: Template }
  | { type: "renamed"; name: string }
  | { type: "selectionChanged"; next: ServiceCode[]; notice?: Notice | null }
  | { type: "noticeShown"; notice: Notice }
  | { type: "noticeDismissed" }
  | { type: "confirmationRequested"; confirmation: Confirmation }
  | { type: "confirmed" }
  | { type: "cancelled" };

export const initialBuilderState: BuilderState = {
  packageId: null,
  name: "",
  selected: [],
  baseline: null,
  notice: null,
  confirmation: null,
};

export function builderReducer(state: BuilderState, action: BuilderAction): BuilderState {
  switch (action.type) {
    case "loaded":
      return {
        ...initialBuilderState,
        packageId: action.pkg.id,
        name: action.pkg.name,
        selected: action.pkg.service_codes,
        baseline: { name: action.pkg.name, selected: action.pkg.service_codes },
        notice: action.pkg.violations.length
          ? {
              tone: "warning",
              title: "This package no longer meets the current rules",
              message: action.pkg.violations.map((v) => v.message).join(". "),
            }
          : null,
      };

    case "saved":
      return {
        ...state,
        packageId: action.pkg.id,
        name: action.pkg.name,
        selected: action.pkg.service_codes,
        baseline: { name: action.pkg.name, selected: action.pkg.service_codes },
        confirmation: null,
        notice: {
          tone: "success",
          title: action.created ? "Package saved" : "Changes saved",
          message: `"${action.pkg.name}" has been ${action.created ? "created" : "updated"}.`,
        },
      };

    case "reset":
      return initialBuilderState;

    case "templateApplied":
      return {
        ...initialBuilderState,
        name: action.template.name,
        selected: action.template.service_codes,
        notice: {
          tone: "info",
          title: `Started from the ${action.template.name} template`,
          message: "Adjust the services and save it under your own name.",
        },
      };

    case "renamed":
      return { ...state, name: action.name };

    case "selectionChanged":
      return {
        ...state,
        selected: action.next,
        confirmation: null,
        notice: action.notice === undefined ? clearTransient(state.notice) : action.notice,
      };

    case "noticeShown":
      return { ...state, notice: action.notice };

    case "noticeDismissed":
      return { ...state, notice: null };

    case "confirmationRequested":
      return { ...state, confirmation: action.confirmation };

    case "confirmed":
      if (!state.confirmation) return state;
      return { ...state, selected: state.confirmation.next, confirmation: null, notice: null };

    case "cancelled":
      return { ...state, confirmation: null };
  }
}

/** Notices describe the last action; once the selection changes only informational ones still apply. */
function clearTransient(notice: Notice | null) {
  return notice?.tone === "info" ? notice : null;
}

export function isDirty(state: BuilderState) {
  if (!state.baseline) return state.selected.length > 0 || state.name.trim() !== "";
  return (
    state.baseline.name !== state.name ||
    state.baseline.selected.length !== state.selected.length ||
    state.baseline.selected.some((code, i) => state.selected[i] !== code)
  );
}
