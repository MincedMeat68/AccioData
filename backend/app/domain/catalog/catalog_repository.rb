# frozen_string_literal: true

module Domain
  module Catalog
    # Port for loading the reference catalog. Implemented by
    # Infrastructure::Persistence::SequelCatalogRepository.
    module CatalogRepository
      def load = raise(NotImplementedError) # -> ServiceCatalog
    end
  end
end
