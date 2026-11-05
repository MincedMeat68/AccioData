# frozen_string_literal: true

module Http
  # Domain/application objects -> JSON-ready hashes. Money is always sent as
  # integer cents (`*_cents`); the frontend formats it.
  module Serializers
    module_function

    def catalog(catalog, priced_templates)
      {
        categories: catalog.categories.map { |c| { code: c.code, name: c.name } },
        services: catalog.services.map { |s| service(s) },
        rules: {
          requirements: catalog.requirements.map { |r| { service: r.service_code, requires: r.requires_code } },
          conflicts: catalog.conflicts.map do |c|
            { service: c.service_code, conflicts_with: c.conflicts_with_code, supersedes: c.supersedes, reason: c.reason }
          end
        },
        discounts: catalog.discount_rules.map { |d| discount_rule(d) },
        templates: priced_templates.map { |t| template(t) }
      }
    end

    def service(s)
      { code: s.code, name: s.name, category: s.category_code, price_cents: s.price.cents, description: s.description }
    end

    def discount_rule(rule)
      case rule
      when Domain::Pricing::Discounts::VolumeDiscount
        { type: "volume", code: rule.code,
          tiers: rule.tiers.map { |t| { min_services: t.min_services, percent: t.percent } } }
      when Domain::Pricing::Discounts::BundleDiscount
        { type: "bundle", code: rule.code, name: rule.name, service_codes: rule.service_codes,
          amount_cents: rule.amount.cents }
      else
        { type: "other", code: rule.code }
      end
    end

    def template(priced)
      t = priced.template
      { code: t.code, name: t.name, service_codes: t.service_codes, quote: quote(priced.quote) }
    end

    def quote(q)
      {
        line_items: q.line_items.map { |li| { service_code: li.service_code, name: li.name, price_cents: li.price.cents } },
        service_count: q.service_count,
        subtotal_cents: q.subtotal.cents,
        discounts: q.discounts.map { |d| { code: d.code, label: d.label, amount_cents: d.amount.cents } },
        discount_total_cents: q.discount_total.cents,
        total_cents: q.total.cents
      }
    end

    def violation(v)
      { type: v.type.to_s, service_code: v.service_code, related_codes: v.related_codes, message: v.message }
    end

    def availability(a)
      { service_code: a.service_code, status: a.status.to_s,
        violations: a.violations.map { |v| violation(v) }, removal_cascade: a.removal_cascade }
    end

    def evaluation(e)
      {
        valid: e.violations.empty?,
        quote: quote(e.quote),
        violations: e.violations.map { |v| violation(v) },
        availability: e.availability.map { |a| availability(a) }
      }
    end

    def package(priced)
      p = priced.package
      {
        id: p.id,
        name: p.name,
        service_codes: p.service_codes,
        created_at: p.created_at&.utc&.iso8601,
        updated_at: p.updated_at&.utc&.iso8601,
        quote: quote(priced.quote),
        violations: priced.violations.map { |v| violation(v) }
      }
    end
  end
end
