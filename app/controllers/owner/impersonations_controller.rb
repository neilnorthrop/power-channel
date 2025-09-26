# frozen_string_literal: true

module Owner
  class ImpersonationsController < BaseController
    def start
      user = User.find(params[:id])
      if user.owner? && user != current_actor
        return redirect_to owner_users_path, alert: "Cannot impersonate another owner."
      end
      session[:impersonated_user_id] = user.id
      OwnerAuditLog.create!(actor: current_actor, target_user: user, action: "impersonation.start")
      redirect_to root_path, notice: "Now viewing as #{user.email}."
    end

    def stop
      if session[:impersonated_user_id]
        target = User.find_by(id: session[:impersonated_user_id])
        OwnerAuditLog.create!(actor: current_actor, target_user: target, action: "impersonation.stop") if target
      end
      session.delete(:impersonated_user_id)
      redirect_to owner_dashboard_path, notice: "Stopped impersonation."
    end
  end
end

