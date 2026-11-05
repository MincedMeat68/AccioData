import type { Catalog } from "@/lib/api/types";

/** Mirrors backend/db/seeds/catalog.yml (rules only matter here, not prices). */
export const catalogFixture: Catalog = {
  categories: [
    { code: "criminal", name: "Criminal" },
    { code: "drug_screening", name: "Drug Screening" },
  ],
  services: [
    ["state_criminal", "State Criminal Search", "criminal", 1500],
    ["county_criminal", "County Criminal Search", "criminal", 2500],
    ["federal_criminal", "Federal Criminal Search", "criminal", 3000],
    ["national_criminal", "National Criminal Database", "criminal", 4000],
    ["mvr", "Motor Vehicle Report (MVR)", "driving", 2000],
    ["drug_5_panel", "Drug Test (5-Panel)", "drug_screening", 4500],
    ["drug_10_panel", "Drug Test (10-Panel)", "drug_screening", 6500],
  ].map(([code, name, category, price]) => ({
    code: code as string,
    name: name as string,
    category: category as string,
    price_cents: price as number,
    description: null,
  })),
  rules: {
    requirements: [
      { service: "county_criminal", requires: "state_criminal" },
      { service: "federal_criminal", requires: "state_criminal" },
    ],
    conflicts: [
      {
        service: "drug_10_panel",
        conflicts_with: "drug_5_panel",
        supersedes: true,
        reason: "the 10-Panel includes all 5-Panel tests",
      },
    ],
  },
  discounts: [
    {
      type: "volume",
      code: "volume",
      tiers: [
        { min_services: 8, percent: 15 },
        { min_services: 5, percent: 10 },
      ],
    },
  ],
  templates: [],
};
