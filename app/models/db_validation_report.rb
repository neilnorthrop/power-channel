# frozen_string_literal: true

class DbValidationReport < ApplicationRecord
  enum :status, { ok: "ok", issues: "issues" }
end
