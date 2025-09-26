# frozen_string_literal: true

class OwnerAuditLog < ApplicationRecord
  belongs_to :actor, class_name: "User"
  belongs_to :target_user, class_name: "User", optional: true

  validates :action, presence: true
end

