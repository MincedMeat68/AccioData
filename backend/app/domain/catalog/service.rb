# frozen_string_literal: true

module Domain
  module Catalog
    # A screening service that can be put in a package. Identified by its
    # stable `code`; `price` is a Money.
    Service = Data.define(:code, :name, :category_code, :price, :description)
  end
end
