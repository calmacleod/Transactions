class ClassificationRun < ApplicationRecord
  include UserOwned

  ACTIVE_STATUSES = %w[queued running canceling].freeze
  TERMINAL_STATUSES = %w[complete canceled failed].freeze
  STATUSES = (ACTIVE_STATUSES + TERMINAL_STATUSES).freeze

  validates :status, inclusion: { in: STATUSES }

  scope :latest, -> { order(created_at: :desc) }
  scope :active, -> { where(status: ACTIVE_STATUSES) }

  def active?
    status.in?(ACTIVE_STATUSES)
  end

  def cancellable?
    status.in?(%w[queued running])
  end

  def cancel_requested?
    cancel_requested_at.present?
  end

  def request_cancel!
    update!(status: "canceling", cancel_requested_at: Time.current) if cancellable?
  end

  def start!(total:)
    update!(status: "running", total_count: total, started_at: Time.current)
  end

  def record_batch!(processed:, classified:, rule_based:, ai:, failed:)
    update!(
      processed_count: processed_count + processed,
      classified_count: classified_count + classified,
      rule_based_count: rule_based_count + rule_based,
      ai_count: ai_count + ai,
      failed_count: failed_count + failed
    )
  end

  def complete!
    update!(status: "complete", finished_at: Time.current)
  end

  def cancel!
    update!(status: "canceled", finished_at: Time.current)
  end

  def fail!(error)
    update!(status: "failed", notes: "#{error.class}: #{error.message}", finished_at: Time.current)
  end

  def progress_percent
    return 100 if total_count.zero? && finished_at.present?
    return 0 if total_count.zero?

    ((processed_count.to_f / total_count) * 100).clamp(0, 100).round
  end
end
