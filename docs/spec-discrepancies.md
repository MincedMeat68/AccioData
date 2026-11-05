# Spec discrepancies and how we resolved them

In several places the spec's own figures contradict its business rules. In every case we follow the **rules** and the **Appendix Example 3 arithmetic**: 15% of $230 = $34.50, then −$20, then −$15, giving $160.50. We changed no rule to make a listed figure come out right.

| Where | What the spec says | What the rules give | Why they differ | What we did |
|---|---|---|---|---|
| Appendix Example 4 | "All 10 services": $254.00 | $254.00 is correct arithmetic | Includes **both** drug panels, which the conflict rule forbids | The pricing engine reproduces $254.00 (spec: `pricing_engine_spec.rb`), but the policy won't let such a package be built or saved |
| Template "Comprehensive" | "All except 5-Panel": $254.00 | **$215.75**: $295 − $44.25 (15%) − $20 − $15 | The listed price is the 10-service figure from Example 4 | Template prices are **computed**, not stored. Shows $215.75 |
| Template "Standard" | 7 services: $202.50 | **$182.50**: $225 − $22.50 (10%) − $20 | The criminal bundle is left out, though all 4 criminal searches are included | Computed: $182.50 |
| Template "Basic" | $95.00 | $95.00 | – | Matches |
| Mockup page 12 | 8 services: $195.50 | **$160.50** (the same set as Example 3) | Applies only the volume discount | We follow Example 3 |
| Mockup page 13 | 7 services: $202.50 | $182.50 | Leaves out the criminal bundle | Computed |
| Mockup page 14 "Executive Level" | 8 services, −$54.50: $175.50 | **$160.50** | Leaves out the verification bundle | n/a (sample data only) |
| Flow 1 vs Flow 5 | "Standard Hire Package" has 3 services in Flow 1 but 7 in Flow 5 | – | The name is reused | Both flows work. Names don't need to be unique |
| Flow 3 | "should replace it (or show error)" | – | Leaves the choice to us | Offer to replace, with a confirmation (ADR 0005) |

## Our own interpretations (the spec is silent)

- **Discounts are all calculated from the undiscounted subtotal** and then subtracted, which matches Example 3's arithmetic.
- **Volume tiers are exclusive.** At 8 or more services the discount is 15%, not 10% + 15%.
- **A package needs at least one service and a name** (up to 100 characters) to be saved.
- **Package names don't need to be unique.** Packages are identified by a UUID.
- **"Most recently saved"** means the package with the latest `updated_at`, so editing an older package makes it the latest.
- **Percentages round half-up to the nearest cent** (no example in the spec needs rounding).
