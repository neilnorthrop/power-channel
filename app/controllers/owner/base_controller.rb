# frozen_string_literal: true

module Owner
  class BaseController < ApplicationController
    before_action :require_owner!
  end
end
