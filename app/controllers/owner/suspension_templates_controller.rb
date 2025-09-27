# frozen_string_literal: true

module Owner
  class SuspensionTemplatesController < BaseController
    def index
      @templates = SuspensionTemplate.order(:name)
      @template = SuspensionTemplate.new
    end

    def create
      @template = SuspensionTemplate.new(template_params)
      if @template.save
        OwnerAuditLog.create!(actor: current_actor, action: "suspension_template.create", metadata: { id: @template.id, name: @template.name })
        redirect_to owner_suspension_templates_path, notice: "Template created."
      else
        @templates = SuspensionTemplate.order(:name)
        render :index, status: :unprocessable_entity
      end
    end

    def edit
      @template = SuspensionTemplate.find(params[:id])
    end

    def update
      @template = SuspensionTemplate.find(params[:id])
      if @template.update(template_params)
        OwnerAuditLog.create!(actor: current_actor, action: "suspension_template.update", metadata: { id: @template.id })
        redirect_to owner_suspension_templates_path, notice: "Template updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      template = SuspensionTemplate.find(params[:id])
      template.destroy!
      OwnerAuditLog.create!(actor: current_actor, action: "suspension_template.destroy", metadata: { id: template.id, name: template.name })
      redirect_to owner_suspension_templates_path, notice: "Template deleted."
    end

    private

    def template_params
      params.require(:suspension_template).permit(:name, :content)
    end
  end
end
