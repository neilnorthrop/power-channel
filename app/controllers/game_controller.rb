class GameController < ApplicationController
  before_action :authenticate_user!
  before_action :reject_suspended!

  def index
  end

  def inventory; end
  def skills; end
  def buildings; end
end
