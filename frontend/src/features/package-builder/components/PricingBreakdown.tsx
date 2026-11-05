import type { Quote } from "@/lib/api/types";
import { formatCents, pluralize } from "@/lib/format";

interface PricingBreakdownProps {
  quote: Quote | null;
  pending: boolean;
  error: string | null;
  hint: string | null;
}

/** Subtotal, each discount itemized, and the total, as calculated by the server. */
export function PricingBreakdown({ quote, pending, error, hint }: PricingBreakdownProps) {
  if (error) {
    return <p className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">Pricing unavailable: {error}</p>;
  }

  const q = quote ?? { service_count: 0, subtotal_cents: 0, discounts: [], total_cents: 0, discount_total_cents: 0 };

  return (
    <dl className={`space-y-2 text-sm transition-opacity ${pending ? "opacity-60" : ""}`} aria-busy={pending}>
      <div className="flex justify-between text-slate-600">
        <dt>Subtotal ({pluralize(q.service_count, "service")})</dt>
        <dd>{formatCents(q.subtotal_cents)}</dd>
      </div>

      {q.discounts.length === 0 ? (
        <div className="flex justify-between text-slate-500">
          <dt>No discounts applied</dt>
          <dd>{formatCents(0)}</dd>
        </div>
      ) : (
        q.discounts.map((d) => (
          <div key={d.code} className="flex items-center justify-between">
            <dt>
              <span className="rounded bg-emerald-100 px-2 py-0.5 text-xs font-semibold text-emerald-800">{d.label}</span>
            </dt>
            <dd className="font-medium text-emerald-700">−{formatCents(d.amount_cents)}</dd>
          </div>
        ))
      )}

      {hint && <p className="text-xs text-blue-700">💡 {hint}</p>}

      <div className="flex items-baseline justify-between border-t border-slate-200 pt-3">
        <dt className="text-base font-semibold">Total</dt>
        <dd className={`text-2xl font-bold ${q.discounts.length ? "text-emerald-600" : "text-blue-900"}`}>
          {formatCents(q.total_cents)}
        </dd>
      </div>
      {q.discount_total_cents > 0 && (
        <p className="text-right text-xs text-emerald-700">You save {formatCents(q.discount_total_cents)}</p>
      )}
    </dl>
  );
}
