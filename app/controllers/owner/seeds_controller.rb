# frozen_string_literal: true

module Owner
  class SeedsController < BaseController
    def index
      @latest_report = DbValidationReport.order(created_at: :desc).first
    end

    def validate
      io = StringIO.new
      begin
        Seeds::Loader.apply!(dry_run: true, prune: false, logger: io)
        @status = :ok
      rescue StandardError => e
        @status = :error
        io.puts "\nERROR: #{e.message}\n#{e.backtrace.join("\n")}"
      end
      @log = io.string
      render :index
    end

    def export_all
      YamlExporter.export_all!
      redirect_to owner_seeds_path, notice: "Exported all content to YAML."
    end

    def validate_db
      base = DbValidator.run
      @db_report = SuggestionService.enrich(base)
      render :index
    end

    def run_db_validation
      DbValidationJob.perform_later
      redirect_to owner_seeds_path, notice: "DB validation enqueued. Results will appear after completion."
    end
  end
end
