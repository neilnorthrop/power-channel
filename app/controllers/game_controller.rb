class GameController < ApplicationController
  before_action :authenticate_user!

  def index
  end

  def inventory; end
  def skills; end
  def crafting; end
  def buildings; end
  def events; end
end
