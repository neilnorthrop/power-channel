# frozen_string_literal: true

class SuspensionTemplate < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :content, presence: true
end

