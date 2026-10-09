class AskDraft < ApplicationRecord
  belongs_to :ask
  has_one :user, through: :ask

  STATUSES = %w[pending completed failed].freeze

  validates :status, inclusion: { in: STATUSES }

  def completed? = status == "completed"
  def failed?    = status == "failed"

  # The ask was edited after this draft was written.
  def stale?
    generated_at.present? && ask.updated_at > generated_at
  end

  def to_markdown
    lines = []
    lines << "# #{title}"
    lines << ""
    lines << "_Reworded #{generated_at&.strftime('%Y-%m-%d') || 'at an unknown time'} by #{ENV.fetch('APP_NAME', 'PrayerAsks Demo')}. " \
             "AI-generated: a suggestion in your words, not a prayer. Use it, change it, or keep your own._"
    lines << ""
    lines << body.to_s
    lines << ""
    lines << "_What changed:_ #{what_changed}"
    lines << ""
    if moment_on.present?
      lines << "## The date"
      lines << ""
      lines << "#{moment_name}: #{moment_on.iso8601}"
      lines << ""
    end
    if practical_help_ideas.any?
      lines << "## Practical help people could offer"
      lines << ""
      practical_help_ideas.each { |item| lines << "- **#{item['idea']}**: #{item['why']}" }
      lines << ""
    end
    lines << "## The question you'll be asked afterwards"
    lines << ""
    lines << outcome_question.to_s
    lines << ""
    outcome_answers.each { |answer| lines << "- #{answer}" }
    lines << ""
    if privacy_flags.any?
      lines << "## Details that could identify you"
      lines << ""
      privacy_flags.each { |flag| lines << "- #{flag}" }
      lines << ""
    end
    lines << "## What you wrote"
    lines << ""
    lines << ask.whats_going_on
    lines << ""
    lines << "_Asking for:_ #{ask.asking_for_label}"
    lines << "_Our word for this:_ #{ask.vocabulary_label}"
    lines << "_Posting:_ #{ask.visibility_label}"
    lines.join("\n") + "\n"
  end

  def markdown_filename
    slug = title.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "").presence || "ask"
    "#{slug}-reworded.md"
  end
end
