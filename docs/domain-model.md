# Domain model

## Shared vocabulary

These terms mean the same thing in the code, the API and these docs.

| Term | Meaning |
|---|---|
| **Service** | A screening product that can be added to a package (e.g. *State Criminal Search*). Identified by a stable `code` |
| **Catalog** | The set of services on offer plus the rules about them. Reference data |
| **Requirement** | *A requires B*: A may only be in a package that also contains B |
| **Conflict** | A and B may not be in the same package. If A **supersedes** B, A includes everything B covers, so A can replace B |
| **Package** | A named, ordered selection of services that the user builds and saves |
| **Selection** | The service codes in a package (saved or not) |
| **Violation** | A broken rule, phrased for the end user |
| **Availability** | Whether a service can be added to the current selection: `available`, `selected`, `blocked` (missing prerequisite) or `conflict` |
| **Cascade** | The selected services that must also be removed when a prerequisite is removed |
| **Quote** | The calculated price: line items, subtotal, itemized discounts, total |
| **Discount rule** | A strategy that may produce one discount line: *volume* (percentage by service count) or *bundle* (flat amount when a whole set is selected) |
| **Template** | A predefined selection used as a starting point. Its price is always calculated, never stored |

## Model

```mermaid
classDiagram
    direction LR

    class ServiceCatalog {
      <<reference data>>
      categories
      services
      requirements
      conflicts
      discount_rules
      templates
      fetch(code)
      prerequisites_of(code)
      dependents_of(code)
      conflicts_for(code)
    }
    class Service {
      <<value object>>
      code
      name
      category_code
      price: Money
    }
    class RequirementRule {
      <<value object>>
      service_code
      requires_code
    }
    class ConflictRule {
      <<value object>>
      service_code
      conflicts_with_code
      supersedes
      reason
    }

    class Package {
      <<aggregate root>>
      id
      name
      service_codes
      add(code, policy, replace_conflicts)
      remove(code, policy, cascade)
      revise(name, codes, policy)
      duplicate(new_id)
      validate!(policy)
    }
    class SelectionPolicy {
      <<domain service>>
      violations(codes)
      violations_for_add(codes, code)
      removal_cascade(codes, code)
      replaceable_by(codes, code)
      availability(codes)
    }
    class PricingEngine {
      <<domain service>>
      quote(codes) PriceQuote
    }
    class DiscountRule {
      <<strategy>>
      apply(services, subtotal) DiscountLine?
    }
    class VolumeDiscount
    class BundleDiscount
    class PriceQuote {
      <<value object>>
      line_items
      subtotal
      discounts
      total
    }

    ServiceCatalog "1" o-- "*" Service
    ServiceCatalog "1" o-- "*" RequirementRule
    ServiceCatalog "1" o-- "*" ConflictRule
    ServiceCatalog "1" o-- "*" DiscountRule
    DiscountRule <|-- VolumeDiscount
    DiscountRule <|-- BundleDiscount
    SelectionPolicy ..> ServiceCatalog : interprets
    PricingEngine ..> ServiceCatalog : uses
    PricingEngine ..> PriceQuote : produces
    Package ..> SelectionPolicy : asks before every change
    Package ..> Service : references by code
```

## Package invariants

The `Package` aggregate checks these on every change. A change that would break one raises `Domain::ValidationError` carrying **all** the violations, and the package is left unchanged.

1. The name is present and at most 100 characters.
2. At least one service is selected, with no duplicates and no unknown codes.
3. Every selected service's prerequisites are also selected.
4. No two selected services conflict.

Changes that need the user's agreement have to be requested explicitly: `remove(..., cascade: true)` and `add(..., replace_conflicts: true)` (see [ADR 0005](adr/0005-dependent-removal-and-conflict-ux.md)).

## Where each concept lives

| Concept | Backend | Frontend |
|---|---|---|
| Rules (data) | `services`, `service_requirements`, `service_conflicts` tables; `SequelCatalogRepository` | Received from `GET /api/catalog` |
| Rule interpretation | `SelectionPolicy` (has final say on save) | `selectionRules.ts` (instant feedback; the same rule data, interpreted generically) |
| Pricing | `PricingEngine` + discount strategies (**the only implementation**) | Shows the result of `POST /api/packages/evaluate` |
| Package lifecycle | `Package` aggregate, `PackageService` use cases, `SequelPackageRepository` | `builderReducer` (draft state), `usePackageBuilder` |

## Database schema

```mermaid
erDiagram
    categories ||--o{ services : groups
    services ||--o{ service_requirements : "service / requires"
    services ||--o{ service_conflicts : "service / conflicts_with"
    package_templates ||--o{ package_template_items : contains
    services ||--o{ package_template_items : ""
    packages ||--o{ package_items : contains
    services ||--o{ package_items : ""

    services { string code PK
               string name
               string category_code FK
               int price_cents
               string description
               int position }
    discount_rules { string code PK
                     string type
                     string name
                     json params
                     int position }
    packages { string id PK "UUID"
               string name
               datetime created_at
               datetime updated_at }
    package_items { string package_id FK
                    string service_code FK
                    int position }
```
