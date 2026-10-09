class Ask < ApplicationRecord
  belongs_to :user
  has_many :ask_drafts, dependent: :destroy
  has_one :latest_ask_draft,
          -> { order(generated_at: :desc, created_at: :desc) },
          class_name: "AskDraft"

  ASKING_FOR   = %w[prayer practical_help both].freeze
  VOCABULARIES = %w[prayer devotional carrying].freeze
  VISIBILITIES = %w[named anonymous].freeze

  # Production caps the asker's draft at 2,000 characters (PRD §9, ask_rewording.ask_text).
  MAX_LENGTH = 2000

  # Form labels.
  ASKING_FOR_LABELS = {
    "prayer"         => "To be held (prayer, devotion, or simply carried)",
    "practical_help" => "Practical help",
    "both"           => "Both"
  }.freeze

  VOCABULARY_LABELS = {
    "prayer"     => "Prayer",
    "devotional" => "Devotional",
    "carrying"   => "Carrying (no religious words)"
  }.freeze

  VISIBILITY_LABELS = {
    "named"     => "Named: people see it is from me",
    "anonymous" => "Anonymous: no one sees who wrote it"
  }.freeze

  # The phrases the prayerasks_ask_v1 template receives.
  ASKING_FOR_PROMPTS = {
    "prayer"         => "to be held by the community (in our word for this), not practical help",
    "practical_help" => "practical help only",
    "both"           => "both: to be held by the community (in our word for this), and practical help"
  }.freeze

  VISIBILITY_PROMPTS = {
    "named"     => "named: the community sees who wrote it",
    "anonymous" => "anonymous: no one, including the facilitator, can see who wrote it"
  }.freeze

  validates :whats_going_on, presence: true, length: { in: 20..MAX_LENGTH }
  validates :asking_for,     presence: true, inclusion: { in: ASKING_FOR }
  validates :vocabulary,     presence: true, inclusion: { in: VOCABULARIES }
  validates :visibility,     presence: true, inclusion: { in: VISIBILITIES }

  def anonymous?   = visibility == "anonymous"
  def prayer_only? = asking_for == "prayer"

  def asking_for_label = ASKING_FOR_LABELS.fetch(asking_for, asking_for.to_s.humanize)
  def vocabulary_label = VOCABULARY_LABELS.fetch(vocabulary, vocabulary.to_s.humanize)
  def visibility_label = VISIBILITY_LABELS.fetch(visibility, visibility.to_s.humanize)

  # A short line for the dashboard and page titles, from the member's own words.
  def summary(length = 80)
    whats_going_on.to_s.squish.truncate(length, separator: " ")
  end

  # Variables for the prayerasks_ask_v1 template. Nothing about the asker (name, email) is sent.
  def ai_variables
    {
      whats_going_on: whats_going_on,
      input_length:   whats_going_on.length.to_s,
      asking_for:     ASKING_FOR_PROMPTS.fetch(asking_for),
      moment_on:      moment_on&.iso8601 || "No date given",
      vocabulary:     vocabulary,
      visibility:     VISIBILITY_PROMPTS.fetch(visibility)
    }
  end
end
