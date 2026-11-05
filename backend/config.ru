# frozen_string_literal: true

require_relative "config/boot"

db = Infrastructure::Persistence::Database.connect(Container.database_path)
Container.prepare(db)

Http::Api.set :container, Container.new(db: db)
run Http::Api
