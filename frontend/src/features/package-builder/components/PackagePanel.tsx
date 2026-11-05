import type { Catalog, Template } from "@/lib/api/types";
import { formatCents, pluralize } from "@/lib/format";
import type { PackageBuilder } from "../hooks/usePackageBuilder";
import { PricingBreakdown } from "./PricingBreakdown";

interface PackagePanelProps {
  catalog: Catalog;
  builder: PackageBuilder;
}

export function PackagePanel({ catalog, builder }: PackagePanelProps) {
  const { state, evaluation, rules, dirty, saving } = builder;
  const services = state.selected.map((code) => catalog.services.find((s) => s.code === code)).filter((s) => !!s);
  const categoryName = (code: string) => catalog.categories.find((c) => c.code === code)?.name ?? code;
  const editing = state.packageId !== null;
  const canSave = !saving && state.selected.length > 0 && state.name.trim() !== "" && (dirty || !editing);

  return (
    <section aria-labelledby="current-package" className="rounded-xl border border-slate-200 bg-slate-50 p-5">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
        <h2 id="current-package" className="text-lg font-semibold">
          {editing ? "Editing Package" : "Current Package"}
        </h2>
        <div className="flex items-center gap-2">
          {dirty && editing && <span className="text-xs text-amber-700">Unsaved changes</span>}
          <span className="rounded-full bg-blue-100 px-3 py-0.5 text-xs font-semibold text-blue-800">
            {pluralize(state.selected.length, "service")}
          </span>
        </div>
      </div>

      <TemplatePicker templates={catalog.templates} onPick={builder.applyTemplate} />

      {services.length === 0 ? (
        <div className="my-6 flex flex-col items-center py-8 text-center text-slate-500">
          <span aria-hidden className="mb-2 text-4xl">📋</span>
          <p className="font-medium">No services selected yet</p>
          <p className="text-sm">Add services from the left to build your package</p>
        </div>
      ) : (
        <ul className="my-4 space-y-2">
          {services.map((service) => (
            <li key={service.code} className="flex items-center gap-3 rounded-lg border border-slate-200 bg-white px-4 py-2.5">
              <span aria-hidden className="h-2.5 w-2.5 shrink-0 rounded-full bg-emerald-500" />
              <div className="min-w-0 flex-1">
                <p className="text-sm font-medium">{service.name}</p>
                <p className="text-xs text-slate-500">{categoryName(service.category)}</p>
              </div>
              <span className="text-sm font-semibold">{formatCents(service.price_cents)}</span>
              <button
                type="button"
                onClick={() => builder.remove(service.code)}
                aria-label={`Remove ${service.name}`}
                className="flex h-6 w-6 items-center justify-center rounded-full bg-red-500 text-sm font-bold text-white hover:bg-red-600"
              >
                −
              </button>
            </li>
          ))}
        </ul>
      )}

      <div className="border-t border-slate-200 pt-4">
        <PricingBreakdown
          quote={evaluation?.quote ?? null}
          pending={builder.pricingPending}
          error={builder.pricingError}
          hint={rules.nextVolumeTierHint(state.selected.length)}
        />
      </div>

      <form
        className="mt-5 space-y-3"
        onSubmit={(e) => {
          e.preventDefault();
          if (canSave) builder.save();
        }}
      >
        <label className="block">
          <span className="mb-1 block text-sm font-medium">Package Name</span>
          <input
            value={state.name}
            onChange={(e) => builder.rename(e.target.value)}
            placeholder="Enter package name..."
            maxLength={100}
            className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-200"
          />
        </label>
        <button
          type="submit"
          disabled={!canSave}
          className="w-full rounded-md bg-blue-900 py-2.5 text-sm font-semibold text-white hover:bg-blue-800 disabled:cursor-not-allowed disabled:bg-slate-200 disabled:text-slate-400"
        >
          {saving ? "Saving…" : editing ? "Save Changes" : "Save Package"}
        </button>
        {!canSave && !saving && (
          <p className="text-center text-xs text-slate-500">
            {state.selected.length === 0
              ? "Add at least one service to save."
              : state.name.trim() === ""
                ? "Enter a package name to save."
                : "No changes to save."}
          </p>
        )}
        {editing && (
          <div className="flex gap-2">
            <button
              type="button"
              disabled={saving || state.selected.length === 0 || state.name.trim() === ""}
              onClick={() => builder.save({ asNew: true })}
              className="flex-1 rounded-md border border-slate-300 bg-white py-2 text-sm font-medium hover:bg-slate-50 disabled:opacity-50"
            >
              Save as New
            </button>
            <button
              type="button"
              onClick={builder.reset}
              className="flex-1 rounded-md border border-slate-300 bg-white py-2 text-sm font-medium hover:bg-slate-50"
            >
              Start New Package
            </button>
          </div>
        )}
      </form>
    </section>
  );
}

function TemplatePicker({ templates, onPick }: { templates: Template[]; onPick: (t: Template) => void }) {
  if (!templates.length) return null;
  return (
    <label className="flex items-center gap-2 text-sm">
      <span className="shrink-0 text-slate-600">Start from template:</span>
      <select
        value=""
        onChange={(e) => {
          const template = templates.find((t) => t.code === e.target.value);
          if (template) onPick(template);
        }}
        className="min-w-0 flex-1 rounded-md border border-slate-300 bg-white px-2 py-1.5"
      >
        <option value="">Choose…</option>
        {templates.map((t) => (
          <option key={t.code} value={t.code}>
            {t.name} ({pluralize(t.service_codes.length, "service")}, {formatCents(t.quote.total_cents)})
          </option>
        ))}
      </select>
    </label>
  );
}
