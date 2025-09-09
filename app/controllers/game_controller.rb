class GameController < ApplicationController
  before_action :authenticate_user!

  def index
  end

  def inventory; end
  def skills; end
  def buildings; end
end
