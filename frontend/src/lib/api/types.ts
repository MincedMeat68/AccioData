// Shapes of the Sinatra API's JSON (see docs/api.md). Money is integer cents.

export type ServiceCode = string;

export interface Category {
  code: string;
  name: string;
}

export interface Service {
  code: ServiceCode;
  name: string;
  category: string;
  price_cents: number;
  description: string | null;
}

export interface RequirementRule {
  service: ServiceCode;
  requires: ServiceCode;
}

export interface ConflictRule {
  service: ServiceCode;
  conflicts_with: ServiceCode;
  /** `service` fully includes `conflicts_with`, so replacing is safe. */
  supersedes: boolean;
  reason: string | null;
}

export type DiscountRule =
  | { type: "volume"; code: string; tiers: { min_services: number; percent: number }[] }
  | { type: "bundle"; code: string; name: string; service_codes: ServiceCode[]; amount_cents: number }
  | { type: "other"; code: string };

export interface DiscountLine {
  code: string;
  label: string;
  amount_cents: number;
}

export interface Quote {
  line_items: { service_code: ServiceCode; name: string; price_cents: number }[];
  service_count: number;
  subtotal_cents: number;
  discounts: DiscountLine[];
  discount_total_cents: number;
  total_cents: number;
}

export interface Violation {
  type: string;
  service_code: ServiceCode | null;
  related_codes: ServiceCode[];
  message: string;
}

export interface Template {
  code: string;
  name: string;
  service_codes: ServiceCode[];
  quote: Quote;
}

export interface Catalog {
  categories: Category[];
  services: Service[];
  rules: { requirements: RequirementRule[]; conflicts: ConflictRule[] };
  discounts: DiscountRule[];
  templates: Template[];
}

export interface Evaluation {
  valid: boolean;
  quote: Quote;
  violations: Violation[];
}

export interface SavedPackage {
  id: string;
  name: string;
  service_codes: ServiceCode[];
  created_at: string;
  updated_at: string;
  quote: Quote;
  violations: Violation[];
}

export interface PackageInput {
  name: string;
  service_codes: ServiceCode[];
}
