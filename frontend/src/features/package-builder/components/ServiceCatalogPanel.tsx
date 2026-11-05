import type { Catalog, ServiceCode } from "@/lib/api/types";
import type { SelectionRules } from "../rules/selectionRules";
import type { Notice } from "../state/builderReducer";
import { ServiceCard } from "./ServiceCard";

interface ServiceCatalogPanelProps {
  catalog: Catalog;
  rules: SelectionRules;
  selected: ServiceCode[];
  notice: Notice | null;
  onAdd: (code: ServiceCode) => void;
  onRemove: (code: ServiceCode) => void;
}

export function ServiceCatalogPanel({ catalog, rules, selected, notice, onAdd, onRemove }: ServiceCatalogPanelProps) {
  const flaggedCode = notice?.serviceCode;
  const flagTone = notice?.tone === "error" ? "error" : notice?.tone === "warning" ? "warning" : null;

  return (
    <section aria-labelledby="available-services">
      <h2 id="available-services" className="mb-3 text-lg font-semibold">
        Available Services
      </h2>
      <div className="space-y-5">
        {catalog.categories.map((category) => {
          const services = catalog.services.filter((s) => s.category === category.code);
          if (!services.length) return null;
          const added = services.filter((s) => selected.includes(s.code)).length;
          return (
            <div key={category.code}>
              <h3 className="mb-2 flex items-baseline gap-2 text-xs font-semibold tracking-wide text-slate-500 uppercase">
                {category.name}
                {added > 0 && <span className="font-normal normal-case">({added} added)</span>}
              </h3>
              <ul className="space-y-2">
                {services.map((service) => (
                  <ServiceCard
                    key={service.code}
                    service={service}
                    availability={rules.availability(selected, service.code)}
                    flagged={flaggedCode === service.code ? flagTone : null}
                    onAdd={() => onAdd(service.code)}
                    onRemove={() => onRemove(service.code)}
                  />
                ))}
              </ul>
            </div>
          );
        })}
      </div>
    </section>
  );
}
