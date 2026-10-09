# Code-side guard on AI output (not trusted to the model): PrayerAsks never writes a prayer, a blessing, or
# scripture. Adapted from production PrayerAsks' PrayerMarkerCheck, which discards any output carrying a prayer
# marker the input did not have.
#
# The demo's list is wider than production's four markers: it adds forms of address ("Dear God", "Heavenly
# Father", "O Lord"), closings ("Amen", "in Jesus' name"), invocations ("May God ...", "let us pray"), and
# scripture citations ("Psalm 23", "John 3:16", "Surah 2:286").
#
# A marker the member wrote themselves may come back: rewording keeps the asker's own words ("God bless you
# all" in the input can stay in the output). Anything the model added is a failure.
module NoPrayerCheck
  BOOKS = %w[
    Genesis Exodus Leviticus Numbers Deuteronomy Joshua Judges Ruth Samuel Kings Chronicles Ezra Nehemiah Esther
    Job Proverbs Ecclesiastes Isaiah Jeremiah Lamentations Ezekiel Daniel Hosea Joel Amos Obadiah Jonah Micah
    Nahum Habakkuk Zephaniah Haggai Zechariah Malachi Matthew Mark Luke John Acts Romans Corinthians Galatians
    Ephesians Philippians Colossians Thessalonians Timothy Titus Philemon Hebrews James Peter Jude Revelation
    Sirach Wisdom Tobit Maccabees
  ].freeze

  MARKERS = {
    "Dear God"            => /\bdear\s+(god|lord|father|jesus)\b/i,
    "Heavenly Father"     => /\bheavenly\s+father\b/i,
    "Lord"                => /\blord\b/i,
    "O God"               => /\bO\s+(god|lord)\b/,
    "we pray"             => /\b(?:we|i)\s+pray\b|\blet\s+us\s+pray\b/i,
    "May God"             => /\bmay\s+(god|the\s+lord|allah|the\s+divine|the\s+universe)\b/i,
    "bless"               => /\bbless(ed|es|ing|ings)?\b/i,
    "Amen"                => /\bamen\b/i,
    "in Jesus' name"      => /\bin\s+(jesus|christ)['’]?s?\s+name\b/i,
    # Book names are case-sensitive, so "my job 9:30 start" is not "Job 9:30".
    "scripture citation"  => /\b(?:[123]\s?)?(?:#{BOOKS.join('|')})\s+\d{1,3}:\d{1,3}\b|\b(?i:psalms?)\s+\d{1,3}\b|\b(?i:surah|sura|qur['’]?an)\s+\d{1,3}(?::\d{1,3})?\b/
  }.freeze

  # Labels of the markers in `output` that `input` does not already contain (empty when the output is clean).
  def self.found_in(output, input = "")
    MARKERS.filter_map { |label, pattern| label if output.to_s.match?(pattern) && !input.to_s.match?(pattern) }
  end

  def self.clean?(output, input = "")
    found_in(output, input).empty?
  end
end
