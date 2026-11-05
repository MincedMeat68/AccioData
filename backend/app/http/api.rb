# frozen_string_literal: true

require "json"
require "sinatra/base"

module Http
  # Thin HTTP adapter: parse the request, call one application use case,
  # serialize the result. No business rules live here.
  class Api < Sinatra::Base
    class BadRequest < StandardError; end

    configure do
      set :show_exceptions, false
      set :raise_errors, false
      set :dump_errors, false
      # The API is only reached through the Next.js proxy (or Docker's
      # internal network, where the Host is "backend"), so skip Sinatra's
      # development-mode host allowlist.
      set :host_authorization, { permitted_hosts: [] }
    end

    before { content_type :json }

    helpers do
      def container = settings.container
      def catalog_queries = container.catalog_queries
      def packages = container.package_service

      def body_params
        @body_params ||= begin
          raw = request.body.read
          raw.strip.empty? ? {} : JSON.parse(raw)
        rescue JSON::ParserError
          raise BadRequest, "Request body must be valid JSON"
        end
        raise BadRequest, "Request body must be a JSON object" unless @body_params.is_a?(Hash)

        @body_params
      end

      def service_codes_param
        codes = body_params.fetch("service_codes", [])
        unless codes.is_a?(Array) && codes.all? { |c| c.is_a?(String) }
          raise BadRequest, "service_codes must be an array of strings"
        end

        codes
      end

      def json(data, status: 200)
        self.status status
        JSON.generate(data)
      end

      def error_json(status, code, message, violations: [])
        json({ error: { code: code, message: message, violations: violations } }, status: status)
      end
    end

    # --- Catalog ----------------------------------------------------------

    get "/api/health" do
      json({ status: "ok" })
    end

    # Services plus the rules and discounts as data, so the UI can show
    # availability instantly. Pricing stays server-side.
    get "/api/catalog" do
      json(Serializers.catalog(catalog_queries.catalog, catalog_queries.templates))
    end

    get "/api/services" do
      json(catalog_queries.catalog.services.map { |s| Serializers.service(s) })
    end

    get "/api/templates" do
      json(catalog_queries.templates.map { |t| Serializers.template(t) })
    end

    # --- Unsaved selections -------------------------------------------------

    # Price + violations + per-service availability in one round trip.
    post "/api/packages/evaluate" do
      json(Serializers.evaluation(catalog_queries.evaluate(service_codes_param)))
    end

    post "/api/packages/price" do
      json(Serializers.quote(catalog_queries.evaluate(service_codes_param).quote))
    end

    post "/api/packages/validate" do
      evaluation = catalog_queries.evaluate(service_codes_param)
      json({ valid: evaluation.violations.empty?,
             violations: evaluation.violations.map { |v| Serializers.violation(v) } })
    end

    # --- Saved packages ----------------------------------------------------

    get "/api/packages" do
      json(packages.list.map { |p| Serializers.package(p) })
    end

    # The most recently saved package; 204 when nothing has been saved yet.
    get "/api/packages/latest" do
      latest = packages.latest
      if latest
        json(Serializers.package(latest))
      else
        status 204
        ""
      end
    end

    get "/api/packages/:id" do
      json(Serializers.package(packages.get(id: params[:id])))
    end

    post "/api/packages" do
      created = packages.create(name: body_params["name"], service_codes: service_codes_param)
      json(Serializers.package(created), status: 201)
    end

    put "/api/packages/:id" do
      updated = packages.update(id: params[:id], name: body_params["name"], service_codes: service_codes_param)
      json(Serializers.package(updated))
    end

    delete "/api/packages/:id" do
      packages.delete(id: params[:id])
      status 204
      ""
    end

    post "/api/packages/:id/duplicate" do
      copy = packages.duplicate(id: params[:id], name: body_params["name"])
      json(Serializers.package(copy), status: 201)
    end

    # --- Errors ------------------------------------------------------------

    error Domain::ValidationError do
      e = env["sinatra.error"]
      error_json(422, "validation_failed", "The package breaks one or more rules",
                 violations: e.violations.map { |v| Serializers.violation(v) })
    end

    error Application::NotFound do
      error_json(404, "not_found", env["sinatra.error"].message)
    end

    error BadRequest do
      error_json(400, "bad_request", env["sinatra.error"].message)
    end

    not_found do
      error_json(404, "not_found", "No route for #{request.request_method} #{request.path_info}")
    end

    error StandardError do
      e = env["sinatra.error"]
      warn "[api] #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}"
      error_json(500, "internal_error", "Something went wrong on our side")
    end
  end
end
