# frozen_string_literal: true

class DbValidationJob < ApplicationJob
  queue_as :default

  def perform
    report = DbValidator.run
    issues_count = report.values.flatten.size
    status = issues_count.zero? ? "ok" : "issues"
    DbValidationReport.create!(status: status, issues_count: issues_count, report: report)
  ensure
    # Reschedule to run again in ~24 hours
    self.class.set(wait: 24.hours).perform_later
  end
end
