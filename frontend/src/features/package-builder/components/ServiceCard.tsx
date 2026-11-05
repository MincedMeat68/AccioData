import type { Service } from "@/lib/api/types";
import { formatCents } from "@/lib/format";
import type { Availability } from "../rules/selectionRules";

interface ServiceCardProps {
  service: Service;
  availability: Availability;
  /** The user just tried to add this and was refused. */
  flagged: "error" | "warning" | null;
  onAdd: () => void;
  onRemove: () => void;
}

/**
 * Visual states: available, selected, blocked (missing prerequisite),
 * conflict, and error (a refused add attempt). Blocked services stay
 * clickable (aria-disabled, not disabled) so clicking explains why.
 */
export function ServiceCard({ service, availability, flagged, onAdd, onRemove }: ServiceCardProps) {
  const { status } = availability;
  const selected = status === "selected";

  const card = flagged === "error"
    ? "border-red-400 bg-red-50 ring-2 ring-red-200"
    : flagged === "warning" || status === "conflict"
      ? "border-amber-300 bg-amber-50"
      : selected
        ? "border-emerald-300 bg-emerald-50"
        : status === "blocked"
          ? "border-slate-200 bg-slate-50"
          : "border-slate-200 bg-white hover:border-blue-300";

  const detail =
    status === "selected" ? (
      <span className="text-emerald-700">Added to package</span>
    ) : status === "blocked" ? (
      <span className={flagged === "error" ? "font-medium text-red-700" : "text-slate-500"}>⚠ {availability.reason}</span>
    ) : status === "conflict" ? (
      <span className="text-amber-800">⚠ {availability.reason}</span>
    ) : null;

  return (
    <li className={`flex items-center gap-3 rounded-lg border px-4 py-3 transition-colors ${card}`}>
      {selected && (
        <span aria-hidden className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-emerald-500 text-xs text-white">
          ✓
        </span>
      )}
      <div className="min-w-0 flex-1">
        <p className={`font-semibold ${status === "blocked" && !flagged ? "text-slate-500" : "text-slate-900"}`}>{service.name}</p>
        {service.description && <p className="text-xs text-slate-500">{service.description}</p>}
        {detail && <p className="mt-1 text-xs">{detail}</p>}
      </div>
      <span className={`shrink-0 font-semibold ${selected ? "text-emerald-700" : "text-blue-900"}`}>
        {formatCents(service.price_cents)}
      </span>
      {selected ? (
        <button
          type="button"
          onClick={onRemove}
          aria-label={`Remove ${service.name}`}
          className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md border border-red-200 bg-white text-lg font-bold text-red-600 hover:bg-red-50"
        >
          −
        </button>
      ) : (
        <button
          type="button"
          onClick={onAdd}
          aria-label={`Add ${service.name}`}
          aria-disabled={status === "blocked"}
          title={status === "blocked" || status === "conflict" ? availability.reason : undefined}
          className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-md text-lg font-bold ${
            status === "blocked"
              ? "cursor-not-allowed bg-slate-200 text-slate-400"
              : status === "conflict"
                ? "bg-amber-200 text-amber-900 hover:bg-amber-300"
                : "bg-blue-600 text-white hover:bg-blue-700"
          }`}
        >
          +
        </button>
      )}
    </li>
  );
}
