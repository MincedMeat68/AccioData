import { describe, expect, it } from "vitest";
import { catalogFixture } from "../testing/catalogFixture";
import { createSelectionRules } from "./selectionRules";

const rules = createSelectionRules(catalogFixture);

describe("availability", () => {
  it("blocks County and Federal until State is selected (Flow 2)", () => {
    expect(rules.availability([], "county_criminal")).toEqual({
      status: "blocked",
      missing: ["state_criminal"],
      reason: "Requires State Criminal Search",
    });
    expect(rules.availability(["state_criminal"], "county_criminal")).toEqual({ status: "available" });
  });

  it("treats National Criminal as standalone", () => {
    expect(rules.availability([], "national_criminal")).toEqual({ status: "available" });
  });

  it("flags conflicts in both directions, but only offers replacement when superseding", () => {
    const tenPanel = rules.availability(["drug_5_panel"], "drug_10_panel");
    expect(tenPanel).toMatchObject({ status: "conflict", replaceable: ["drug_5_panel"] });

    const fivePanel = rules.availability(["drug_10_panel"], "drug_5_panel");
    expect(fivePanel).toMatchObject({ status: "conflict", replaceable: [] });
  });

  it("reports what removing a selected service would cascade to", () => {
    expect(rules.availability(["state_criminal", "mvr", "county_criminal"], "state_criminal")).toEqual({
      status: "selected",
      removalCascade: ["county_criminal"],
    });
  });
});

describe("decideAdd", () => {
  it("adds a service with no rule in the way", () => {
    expect(rules.decideAdd(["mvr"], "state_criminal")).toEqual({ kind: "add", next: ["mvr", "state_criminal"] });
  });

  it("explains a missing prerequisite with the spec's wording", () => {
    expect(rules.decideAdd([], "county_criminal")).toEqual({
      kind: "blocked",
      message: "County Criminal Search requires State Criminal Search to be added first",
    });
  });

  it("asks before replacing 5-Panel with 10-Panel (Flow 3)", () => {
    const decision = rules.decideAdd(["state_criminal", "drug_5_panel"], "drug_10_panel");
    if (decision.kind !== "confirm") throw new Error(`expected confirm, got ${decision.kind}`);

    expect(decision.confirmation.message).toContain(
      "Drug Test (10-Panel) conflicts with Drug Test (5-Panel) - the 10-Panel includes all 5-Panel tests",
    );
    expect(decision.confirmation.message).toContain("will remove Drug Test (5-Panel)");
    expect(decision.confirmation.cancelLabel).toBe("Cancel - keep Drug Test (5-Panel)");
    expect(decision.confirmation.next).toEqual(["state_criminal", "drug_10_panel"]);
  });

  it("refuses the lesser service when the greater one is selected", () => {
    expect(rules.decideAdd(["drug_10_panel"], "drug_5_panel")).toEqual({
      kind: "conflict",
      message: "Drug Test (5-Panel) conflicts with Drug Test (10-Panel) - the 10-Panel includes all 5-Panel tests",
    });
  });

  it("ignores a service that is already selected", () => {
    expect(rules.decideAdd(["mvr"], "mvr")).toEqual({ kind: "noop" });
  });
});

describe("decideRemove", () => {
  it("removes a service nothing depends on", () => {
    expect(rules.decideRemove(["state_criminal", "county_criminal"], "county_criminal")).toEqual({
      kind: "remove",
      next: ["state_criminal"],
    });
  });

  it("asks before cascading, naming everything that will go", () => {
    const decision = rules.decideRemove(["state_criminal", "county_criminal", "federal_criminal", "mvr"], "state_criminal");
    if (decision.kind !== "confirm") throw new Error(`expected confirm, got ${decision.kind}`);

    expect(decision.confirmation).toMatchObject({
      title: "Remove State Criminal Search?",
      message:
        "County Criminal Search and Federal Criminal Search require State Criminal Search, so they will be " +
        "removed too. 3 services will be removed from your package in total.",
      confirmLabel: "Remove 3 services",
      cancelLabel: "Cancel - keep everything",
      next: ["mvr"],
    });
  });

  it("uses singular wording for one dependent", () => {
    const decision = rules.decideRemove(["state_criminal", "county_criminal"], "state_criminal");
    if (decision.kind !== "confirm") throw new Error("expected confirm");
    expect(decision.confirmation.message).toContain("County Criminal Search requires State Criminal Search, so it will");
    expect(decision.confirmation.confirmLabel).toBe("Remove 2 services");
  });
});

describe("nextVolumeTierHint", () => {
  it("points at the next tier", () => {
    expect(rules.nextVolumeTierHint(4)).toBe("Add 1 more service to get 10% off");
    expect(rules.nextVolumeTierHint(5)).toBe("Add 3 more services to get 15% off");
    expect(rules.nextVolumeTierHint(8)).toBeNull();
    expect(rules.nextVolumeTierHint(0)).toBeNull();
  });
});
