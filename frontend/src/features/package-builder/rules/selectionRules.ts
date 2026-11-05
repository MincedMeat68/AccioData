/**
 * Generic interpreter for the dependency/conflict rules the backend sends as
 * data in GET /api/catalog. It gives the UI instant feedback (disabled
 * buttons, reasons, confirmation prompts) without a round trip.
 *
 * It knows nothing about specific services: change a rule in the database
 * and this follows. The backend re-validates every save and is the only
 * place prices are calculated (docs/adr/0003).
 */
import type { Catalog, ConflictRule, DiscountRule, ServiceCode } from "@/lib/api/types";

export type Availability =
  | { status: "selected"; removalCascade: ServiceCode[] }
  | { status: "available" }
  | { status: "blocked"; missing: ServiceCode[]; reason: string }
  | { status: "conflict"; conflictsWith: ServiceCode[]; replaceable: ServiceCode[]; reason: string };

export interface Confirmation {
  tone: "danger" | "warning";
  title: string;
  message: string;
  confirmLabel: string;
  cancelLabel: string;
  /** The selection to apply if the user confirms. */
  next: ServiceCode[];
}

export type AddDecision =
  | { kind: "add"; next: ServiceCode[] }
  | { kind: "blocked"; message: string }
  | { kind: "conflict"; message: string }
  | { kind: "confirm"; confirmation: Confirmation }
  | { kind: "noop" };

export type RemoveDecision =
  | { kind: "remove"; next: ServiceCode[] }
  | { kind: "confirm"; confirmation: Confirmation }
  | { kind: "noop" };

type RuleData = Pick<Catalog, "services" | "rules"> & { discounts?: DiscountRule[] };

export function createSelectionRules(catalog: RuleData) {
  const names = new Map(catalog.services.map((s) => [s.code, s.name]));
  const { requirements, conflicts } = catalog.rules;

  const name = (code: ServiceCode) => names.get(code) ?? code;
  const listNames = (codes: ServiceCode[]) => joinWithAnd(codes.map(name));

  const prerequisitesOf = (code: ServiceCode) =>
    requirements.filter((r) => r.service === code).map((r) => r.requires);

  const dependentsOf = (code: ServiceCode) =>
    requirements.filter((r) => r.requires === code).map((r) => r.service);

  const missingPrerequisites = (selected: ServiceCode[], code: ServiceCode) =>
    prerequisitesOf(code).filter((p) => !selected.includes(p));

  const otherSide = (rule: ConflictRule, code: ServiceCode) =>
    rule.service === code ? rule.conflicts_with : rule.conflicts_with === code ? rule.service : null;

  /** Conflict rules between `code` and something already selected. */
  const conflictsWithSelection = (selected: ServiceCode[], code: ServiceCode) =>
    conflicts.filter((rule) => {
      const other = otherSide(rule, code);
      return other !== null && selected.includes(other);
    });

  /** Selected services that `code` fully includes and may replace. */
  const replaceableBy = (selected: ServiceCode[], code: ServiceCode) =>
    conflicts
      .filter((rule) => rule.supersedes && rule.service === code && selected.includes(rule.conflicts_with))
      .map((rule) => rule.conflicts_with);

  /** Selected services that depend on `code`, directly or transitively. */
  const removalCascade = (selected: ServiceCode[], code: ServiceCode) => {
    const found = new Set<ServiceCode>();
    const queue = [code];
    while (queue.length) {
      for (const dependent of dependentsOf(queue.shift()!)) {
        if (selected.includes(dependent) && !found.has(dependent)) {
          found.add(dependent);
          queue.push(dependent);
        }
      }
    }
    return selected.filter((c) => found.has(c));
  };

  const conflictMessage = (code: ServiceCode, rule: ConflictRule) => {
    const other = otherSide(rule, code)!;
    return `${name(code)} conflicts with ${name(other)}${rule.reason ? ` - ${rule.reason}` : ""}`;
  };

  const requirementMessage = (code: ServiceCode, missing: ServiceCode[]) =>
    `${name(code)} requires ${listNames(missing)} to be added first`;

  function availability(selected: ServiceCode[], code: ServiceCode): Availability {
    if (selected.includes(code)) return { status: "selected", removalCascade: removalCascade(selected, code) };

    const missing = missingPrerequisites(selected, code);
    if (missing.length) return { status: "blocked", missing, reason: `Requires ${listNames(missing)}` };

    const clashes = conflictsWithSelection(selected, code);
    if (clashes.length) {
      const conflictsWith = clashes.map((rule) => otherSide(rule, code)!);
      return {
        status: "conflict",
        conflictsWith,
        replaceable: replaceableBy(selected, code),
        reason: `Conflicts with ${listNames(conflictsWith)}${clashes[0].reason ? ` - ${clashes[0].reason}` : ""}`,
      };
    }
    return { status: "available" };
  }

  function decideAdd(selected: ServiceCode[], code: ServiceCode): AddDecision {
    if (selected.includes(code)) return { kind: "noop" };

    const missing = missingPrerequisites(selected, code);
    if (missing.length) return { kind: "blocked", message: requirementMessage(code, missing) };

    const clashes = conflictsWithSelection(selected, code);
    if (!clashes.length) return { kind: "add", next: [...selected, code] };

    const replaceable = replaceableBy(selected, code);
    const unresolvable = clashes.filter((rule) => !replaceable.includes(otherSide(rule, code)!));
    if (unresolvable.length) return { kind: "conflict", message: conflictMessage(code, unresolvable[0]) };

    return {
      kind: "confirm",
      confirmation: {
        tone: "warning",
        title: `Replace ${listNames(replaceable)}?`,
        message:
          `${conflictMessage(code, clashes[0])}. ` +
          `Adding ${name(code)} will remove ${listNames(replaceable)} from your package.`,
        confirmLabel: `Replace with ${name(code)}`,
        cancelLabel: `Cancel - keep ${listNames(replaceable)}`,
        next: [...selected.filter((c) => !replaceable.includes(c)), code],
      },
    };
  }

  function decideRemove(selected: ServiceCode[], code: ServiceCode): RemoveDecision {
    if (!selected.includes(code)) return { kind: "noop" };

    const dependents = removalCascade(selected, code);
    const next = selected.filter((c) => c !== code && !dependents.includes(c));
    if (!dependents.length) return { kind: "remove", next };

    const total = dependents.length + 1;
    const one = dependents.length === 1;
    return {
      kind: "confirm",
      confirmation: {
        tone: "danger",
        title: `Remove ${name(code)}?`,
        message:
          `${listNames(dependents)} ${one ? "requires" : "require"} ${name(code)}, ` +
          `so ${one ? "it" : "they"} will be removed too. ` +
          `${total} services will be removed from your package in total.`,
        confirmLabel: `Remove ${total} services`,
        cancelLabel: "Cancel - keep everything",
        next,
      },
    };
  }

  /** "Add 1 more service to get 10% off" - nudges toward the next volume tier. */
  function nextVolumeTierHint(count: number): string | null {
    const volume = catalog.discounts?.find((d) => d.type === "volume");
    if (!volume || volume.type !== "volume") return null;
    const next = [...volume.tiers].sort((a, b) => a.min_services - b.min_services).find((t) => t.min_services > count);
    if (!next || count === 0) return null;
    const needed = next.min_services - count;
    return `Add ${needed} more service${needed === 1 ? "" : "s"} to get ${next.percent}% off`;
  }

  return { name, availability, decideAdd, decideRemove, removalCascade, nextVolumeTierHint };
}

export type SelectionRules = ReturnType<typeof createSelectionRules>;

function joinWithAnd(items: string[]) {
  if (items.length <= 1) return items.join("");
  return `${items.slice(0, -1).join(", ")} and ${items[items.length - 1]}`;
}
