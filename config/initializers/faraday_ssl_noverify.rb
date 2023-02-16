# frozen_string_literal: true

Faraday.default_connection_options = { ssl: { verify: false } }