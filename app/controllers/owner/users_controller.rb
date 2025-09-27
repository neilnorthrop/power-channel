# frozen_string_literal: true

module Owner
  class UsersController < BaseController
    def index
      scope = User.order(created_at: :desc)
      @q = params[:q].to_s.strip
      @role = params[:role].to_s.strip
      @status = params[:status].to_s.strip

      if @q.present?
        scope = scope.where("email ILIKE ?", "%#{@q}%")
      end
      if @role.present? && User.roles.key?(@role)
        scope = scope.where(role: User.roles[@role])
      end
      if User.column_names.include?("suspended")
        if @status == "suspended"
          scope = scope.where(suspended: true)
        elsif @status == "active"
          scope = scope.where(suspended: false)
        end
      end

      @page = [ params[:page].to_i, 1 ].max
      @per = [ [ params[:per].to_i, 1 ].max, 50 ].min
      @per = 20 if params[:per].blank?
      @total_count = scope.count
      @total_pages = (@total_count / @per.to_f).ceil
      @users = scope.offset((@page - 1) * @per).limit(@per)
      @resources = Resource.order(:name)
      @flags = Flag.order(:name)
      @suspension_templates = []
      begin
        if ActiveRecord::Base.connection.data_source_exists?(:suspension_templates)
          @suspension_templates = SuspensionTemplate.order(:name)
        end
      rescue StandardError
        @suspension_templates = []
      end
    end

    def update
      user = User.find(params[:id])
      new_role = params.require(:user).permit(:role)[:role]
      if User.roles.key?(new_role)
        if user.owner? && new_role != "owner" && User.role_owner.count == 1 && user == current_user
          return redirect_to owner_users_path, alert: "Cannot demote the only owner. Assign another owner first."
        end
        user.update!(role: new_role)
        OwnerAuditLog.create!(actor: current_actor, target_user: user, action: "user.role_update", metadata: { role: new_role })
        redirect_to owner_users_path, notice: "Updated role for #{user.email} to #{new_role}."
      else
        redirect_to owner_users_path, alert: "Invalid role."
      end
    end

    def suspend
      user = User.find(params[:id])
      if user.owner?
        return redirect_to owner_users_path, alert: "Cannot suspend an owner account."
      end
      sp = params.fetch(:suspend, {}).permit(:reason, :until)
      hours = params[:hours].to_i if params[:hours].present?
      suspended_until = begin
        if sp[:until].present?
          Time.zone.parse(sp[:until])
        elsif hours && hours > 0
          Time.current + hours.hours
        end
      rescue ArgumentError
        nil
      end
      user.update!(suspended: true, suspended_until: suspended_until, suspension_reason: sp[:reason])
      OwnerAuditLog.create!(actor: current_actor, target_user: user, action: "user.suspend", metadata: { until: suspended_until, reason: sp[:reason] })
      redirect_to owner_users_path, notice: "Suspended #{user.email}."
    end

    def unsuspend
      user = User.find(params[:id])
      user.update!(suspended: false, suspended_until: nil, suspension_reason: nil)
      OwnerAuditLog.create!(actor: current_actor, target_user: user, action: "user.unsuspend")
      redirect_to owner_users_path, notice: "Unsuspended #{user.email}."
    end

    def grant_resource
      user = User.find(params[:id])
      rp = params.require(:grant).permit(:resource_id, :amount)
      resource = Resource.find(rp[:resource_id])
      amount = rp[:amount].to_i
      if amount == 0
        return redirect_to owner_users_path, alert: "Amount must be non-zero."
      end
      ur = UserResource.find_or_create_by!(user: user, resource: resource)
      ur.update!(amount: (ur.amount || 0) + amount)
      OwnerAuditLog.create!(actor: current_actor, target_user: user, action: "user.grant_resource", metadata: { resource_id: resource.id, amount: amount })
      redirect_to owner_users_path, notice: "Granted #{amount} #{resource.name} to #{user.email}."
    end

    def add_flag
      user = User.find(params[:id])
      flag_id = params.require(:flag_id)
      flag = Flag.find(flag_id)
      UserFlag.find_or_create_by!(user: user, flag: flag)
      OwnerAuditLog.create!(actor: current_actor, target_user: user, action: "user.add_flag", metadata: { flag_id: flag.id })
      redirect_to owner_users_path, notice: "Added flag #{flag.name} to #{user.email}."
    end

    def remove_flag
      user = User.find(params[:id])
      flag_id = params.require(:flag_id)
      uf = UserFlag.find_by!(user: user, flag_id: flag_id)
      flag = uf.flag
      uf.destroy!
      OwnerAuditLog.create!(actor: current_actor, target_user: user, action: "user.remove_flag", metadata: { flag_id: flag_id })
      redirect_to owner_users_path, notice: "Removed flag #{flag.name} from #{user.email}."
    end
  end
end
