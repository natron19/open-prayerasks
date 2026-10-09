class AskDraftsController < ApplicationController
  TEMPLATE = "prayerasks_ask_v1".freeze

  before_action :set_ask

  rate_limit to: 10, within: 1.minute, only: :create, by: -> { current_user.id }

  # shared/_ai_error's "Try again" button is a GET to the current path; send it back to the ask.
  def index
    redirect_to ask_path(@ask)
  end

  def show
    @ask_draft = @ask.ask_drafts.find(params[:id])
  end

  def create
    raw = GeminiService.generate(template: TEMPLATE, variables: @ask.ai_variables)

    @ask_draft = @ask.ask_drafts.create!(
      status:       "pending",
      gemini_raw:   raw,
      generated_at: Time.current
    )

    result = parse_draft!(raw)
    @ask_draft.update!(result.merge(status: "completed"))
    redirect_to ask_draft_path(@ask, @ask_draft)

  rescue ParseError => e
    @ask_draft.update!(status: "failed", failure_reason: e.message.truncate(250), gemini_raw: e.raw)
    redirect_to ask_draft_path(@ask, @ask_draft)

  # Crisis terms in the ask: AiGatekeeper raised before any AI call. Must come before GatekeeperError,
  # its parent class.
  rescue GeminiService::CrisisError
    render "shared/ai_error_page", locals: { error_type: :crisis }, status: :unprocessable_entity

  rescue GeminiService::BudgetExceededError
    render "shared/ai_error_page", locals: { error_type: :budget_exceeded }, status: :unprocessable_entity

  rescue GeminiService::GatekeeperError
    render "shared/ai_error_page", locals: { error_type: :gatekeeper_blocked }, status: :unprocessable_entity

  rescue GeminiService::OutputGuardError
    render "shared/ai_error_page", locals: { error_type: :output_blocked }, status: :unprocessable_entity

  rescue GeminiService::TimeoutError
    render "shared/ai_error_page", locals: { error_type: :timeout }, status: :unprocessable_entity

  rescue GeminiService::GeminiError
    render "shared/ai_error_page", locals: { error_type: :error }, status: :unprocessable_entity
  end

  private

  def set_ask
    @ask = current_user.asks.find(params[:ask_id])
  end

  ParseError = Class.new(StandardError) do
    attr_reader :raw
    def initialize(msg, raw:)
      super(msg)
      @raw = raw
    end
  end

  MAX_TITLE_LENGTH = 80
  MAX_PRIVACY_FLAGS = 6

  # Validates the prayerasks_ask_v1 JSON and returns the AskDraft attributes.
  # Hard rules enforced here, not trusted to the model: no prayer, blessing, or scripture (NoPrayerCheck);
  # the reworded body is no longer than what the member wrote; exactly three outcome answers; and no date
  # the member did not give.
  def parse_draft!(raw)
    fail_parse = ->(msg) { raise ParseError.new(msg, raw: raw) }
    input      = @ask.whats_going_on

    stripped = raw.to_s.strip.gsub(/\A```(?:json)?\s*|\s*```\z/, "").strip
    parsed   = JSON.parse(stripped)
    fail_parse.("Expected a JSON object") unless parsed.is_a?(Hash)

    reworded = parsed["reworded_ask"]
    fail_parse.("reworded_ask must have a title and a body") unless reworded.is_a?(Hash) &&
      present_string?(reworded["title"]) && present_string?(reworded["body"])
    title = reworded["title"].strip
    body  = reworded["body"].strip
    fail_parse.("The title is longer than #{MAX_TITLE_LENGTH} characters") if title.length > MAX_TITLE_LENGTH
    if body.length > input.length
      fail_parse.("The reworded ask (#{body.length} characters) was longer than what you wrote (#{input.length})")
    end

    fail_parse.("what_changed is missing") unless present_string?(parsed["what_changed"])
    what_changed = parsed["what_changed"].strip

    moment_name, moment_on = parse_moment(parsed["moment"], fail_parse)

    ideas = parsed["practical_help_ideas"]
    unless ideas.is_a?(Array) && ideas.size <= 3 &&
           ideas.all? { |i| i.is_a?(Hash) && present_string?(i["idea"]) && present_string?(i["why"]) }
      fail_parse.("Expected 0-3 practical_help_ideas, each with an idea and a why")
    end
    if @ask.prayer_only? && ideas.any?
      fail_parse.("The response suggested practical help, but you asked only to be held")
    end
    ideas = ideas.map { |i| { "idea" => i["idea"].strip, "why" => i["why"].strip } }

    outcome = parsed["outcome_question"]
    fail_parse.("outcome_question must have a question and answers") unless outcome.is_a?(Hash) &&
      present_string?(outcome["question"]) && outcome["answers"].is_a?(Array)
    answers = string_list(outcome["answers"])
    unless answers&.size == 3
      fail_parse.("Expected exactly 3 outcome answers, got #{outcome['answers'].size}#{answers ? '' : ' (some blank)'}")
    end

    flags = string_list(parsed["privacy_flags"])
    fail_parse.("Expected 0-#{MAX_PRIVACY_FLAGS} privacy_flags") unless flags && flags.size <= MAX_PRIVACY_FLAGS

    output_text = [ title, body, what_changed, moment_name, *ideas.flat_map(&:values), outcome["question"], *answers, *flags ].compact.join("\n")
    markers = NoPrayerCheck.found_in(output_text, input)
    if markers.any?
      fail_parse.("The response included prayer or blessing words (#{markers.join(', ')}), which this app never writes")
    end

    {
      title:                title,
      body:                 body,
      what_changed:         what_changed,
      moment_name:          moment_name,
      moment_on:            moment_on,
      practical_help_ideas: ideas,
      outcome_question:     outcome["question"].strip,
      outcome_answers:      answers,
      privacy_flags:        flags
    }
  rescue JSON::ParserError => e
    raise ParseError.new("JSON parse failed: #{e.message.truncate(120)}", raw: raw)
  end

  # The moment is the member's own date or nothing: the AI names the event but never picks a date.
  def parse_moment(moment, fail_parse)
    if moment.nil?
      fail_parse.("The response left out the date you gave") if @ask.moment_on
      return [ nil, nil ]
    end

    fail_parse.("moment must be null or have a name and occurs_on") unless moment.is_a?(Hash) &&
      present_string?(moment["name"]) && present_string?(moment["occurs_on"])
    fail_parse.("The response added a date you did not give") unless @ask.moment_on
    unless moment["occurs_on"].strip == @ask.moment_on.iso8601
      fail_parse.("The response changed your date to #{moment['occurs_on'].strip.truncate(20)}")
    end
    [ moment["name"].strip.truncate(80), @ask.moment_on ]
  end

  def present_string?(value)
    value.is_a?(String) && value.strip.present?
  end

  # An array of non-blank strings, stripped; nil when the value is anything else.
  def string_list(value)
    return nil unless value.is_a?(Array) && value.all? { |v| present_string?(v) }
    value.map(&:strip)
  end
end
