import { describe, expect, it } from "vitest";
import type { SavedPackage } from "@/lib/api/types";
import { createSelectionRules } from "../rules/selectionRules";
import { catalogFixture } from "../testing/catalogFixture";
import { builderReducer, initialBuilderState, isDirty, type BuilderState } from "./builderReducer";

const rules = createSelectionRules(catalogFixture);

const savedPackage = (overrides: Partial<SavedPackage> = {}): SavedPackage => ({
  id: "pkg-1",
  name: "Standard Hire Package",
  service_codes: ["state_criminal", "county_criminal"],
  created_at: "2026-01-01T00:00:00Z",
  updated_at: "2026-01-01T00:00:00Z",
  quote: {
    line_items: [],
    service_count: 2,
    subtotal_cents: 4000,
    discounts: [],
    discount_total_cents: 0,
    total_cents: 4000,
  },
  violations: [],
  ...overrides,
});

const loaded = (): BuilderState => builderReducer(initialBuilderState, { type: "loaded", pkg: savedPackage() });

describe("builderReducer", () => {
  it("loads a saved package as a clean baseline", () => {
    const state = loaded();
    expect(state.packageId).toBe("pkg-1");
    expect(state.selected).toEqual(["state_criminal", "county_criminal"]);
    expect(isDirty(state)).toBe(false);
  });

  it("warns when a loaded package breaks current rules", () => {
    const pkg = savedPackage({
      violations: [{ type: "conflict", service_code: "x", related_codes: [], message: "X conflicts with Y" }],
    });
    expect(builderReducer(initialBuilderState, { type: "loaded", pkg }).notice).toMatchObject({ tone: "warning" });
  });

  it("cascade confirmation: Cancel leaves the package unchanged", () => {
    const decision = rules.decideRemove(loaded().selected, "state_criminal");
    if (decision.kind !== "confirm") throw new Error("expected confirm");

    const pending = builderReducer(loaded(), { type: "confirmationRequested", confirmation: decision.confirmation });
    const cancelled = builderReducer(pending, { type: "cancelled" });

    expect(cancelled.confirmation).toBeNull();
    expect(cancelled.selected).toEqual(["state_criminal", "county_criminal"]);
    expect(isDirty(cancelled)).toBe(false);
  });

  it("cascade confirmation: Confirm removes the service and its dependents", () => {
    const decision = rules.decideRemove(loaded().selected, "state_criminal");
    if (decision.kind !== "confirm") throw new Error("expected confirm");

    const pending = builderReducer(loaded(), { type: "confirmationRequested", confirmation: decision.confirmation });
    const confirmed = builderReducer(pending, { type: "confirmed" });

    expect(confirmed.selected).toEqual([]);
    expect(isDirty(confirmed)).toBe(true);
  });

  it("clears a stale error notice once the selection changes", () => {
    const withError = builderReducer(initialBuilderState, {
      type: "noticeShown",
      notice: { tone: "error", title: "Cannot add service" },
    });
    expect(builderReducer(withError, { type: "selectionChanged", next: ["mvr"] }).notice).toBeNull();
  });

  it("records a save as the new baseline", () => {
    const edited = builderReducer(loaded(), { type: "renamed", name: "Renamed" });
    expect(isDirty(edited)).toBe(true);

    const saved = builderReducer(edited, { type: "saved", pkg: savedPackage({ name: "Renamed" }), created: false });
    expect(isDirty(saved)).toBe(false);
    expect(saved.notice).toMatchObject({ tone: "success", title: "Changes saved" });
  });

  it("starts an unsaved draft from a template", () => {
    const state = builderReducer(loaded(), {
      type: "templateApplied",
      template: { code: "basic", name: "Basic Package", service_codes: ["state_criminal"], quote: savedPackage().quote },
    });
    expect([state.packageId, state.name, state.selected]).toEqual([null, "Basic Package", ["state_criminal"]]);
  });
});
