# API

Base URL: `http://127.0.0.1:4567`. During development the frontend reaches it through the Next.js proxy at `http://localhost:3000/api/*`.

All request and response bodies are JSON. Money is always given in **integer cents** (`*_cents`).

## Endpoints

| Method | Path | Purpose | Success |
|---|---|---|---|
| GET | `/api/health` | Liveness check | 200 |
| GET | `/api/catalog` | Categories, services, **rules as data**, discount rules, priced templates | 200 |
| GET | `/api/services` | Services only | 200 |
| GET | `/api/templates` | Templates with calculated quotes | 200 |
| POST | `/api/packages/evaluate` | Quote + violations + per-service availability for an unsaved selection | 200 |
| POST | `/api/packages/price` | Quote only | 200 |
| POST | `/api/packages/validate` | `{ valid, violations }` | 200 |
| GET | `/api/packages` | All saved packages, most recently updated first | 200 |
| GET | `/api/packages/latest` | The most recently saved package | 200, or **204** if none |
| GET | `/api/packages/:id` | One package | 200 / 404 |
| POST | `/api/packages` | Create | 201 / 422 |
| PUT | `/api/packages/:id` | Replace name + selection | 200 / 404 / 422 |
| DELETE | `/api/packages/:id` | Delete | 204 / 404 |
| POST | `/api/packages/:id/duplicate` | Copy (optional `name`, defaults to "Copy of …") | 201 / 404 |

## Examples

### `POST /api/packages/evaluate`

```json
{ "service_codes": ["state_criminal", "county_criminal", "federal_criminal", "national_criminal",
                    "employment_verification", "education_verification", "license_verification", "mvr"] }
```

```json
{
  "valid": true,
  "quote": {
    "line_items": [{ "service_code": "state_criminal", "name": "State Criminal Search", "price_cents": 1500 }, "..."],
    "service_count": 8,
    "subtotal_cents": 23000,
    "discounts": [
      { "code": "volume", "label": "Volume Discount (15% for 8+ services)", "amount_cents": 3450 },
      { "code": "criminal_bundle", "label": "Criminal Bundle Discount", "amount_cents": 2000 },
      { "code": "verification_bundle", "label": "Verification Bundle Discount", "amount_cents": 1500 }
    ],
    "discount_total_cents": 6950,
    "total_cents": 16050
  },
  "violations": [],
  "availability": [
    { "service_code": "state_criminal", "status": "selected", "violations": [],
      "removal_cascade": ["county_criminal", "federal_criminal"] },
    { "service_code": "drug_5_panel", "status": "available", "violations": [], "removal_cascade": [] }
  ]
}
```

### `POST /api/packages` (invalid)

```json
{ "name": "", "service_codes": ["county_criminal", "drug_5_panel", "drug_10_panel"] }
```

`422 Unprocessable Entity`:

```json
{
  "error": {
    "code": "validation_failed",
    "message": "The package breaks one or more rules",
    "violations": [
      { "type": "invalid_name", "service_code": null, "related_codes": [], "message": "Package name is required" },
      { "type": "missing_requirement", "service_code": "county_criminal", "related_codes": ["state_criminal"],
        "message": "County Criminal Search requires State Criminal Search to be added first" },
      { "type": "conflict", "service_code": "drug_10_panel", "related_codes": ["drug_5_panel"],
        "message": "Drug Test (10-Panel) conflicts with Drug Test (5-Panel) - the 10-Panel includes all 5-Panel tests" }
    ]
  }
}
```

## Errors

Every error uses the same envelope: `{ "error": { "code", "message", "violations": [] } }`.

| Status | `code` | When |
|---|---|---|
| 400 | `bad_request` | Body is not a JSON object, or `service_codes` is not an array of strings |
| 404 | `not_found` | Unknown package id or route |
| 422 | `validation_failed` | The package would break a rule; `violations` lists every problem |
| 500 | `internal_error` | Unexpected error (logged on the server) |

Violation `type`s: `missing_requirement`, `conflict`, `unknown_service`, `duplicate_service`, `invalid_name`, `empty_package`, plus `already_selected`, `not_selected` and `has_dependents` from the domain's add/remove operations.
