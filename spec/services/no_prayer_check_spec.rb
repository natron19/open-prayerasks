require "rails_helper"

RSpec.describe NoPrayerCheck do
  describe ".found_in" do
    {
      "Dear God, please keep her safe."          => "Dear God",
      "Heavenly Father, hold her close."         => "Heavenly Father",
      "Lord, we lift her up to you."             => "Lord",
      "We pray that the surgery goes well."      => "we pray",
      "Let us pray for her."                     => "we pray",
      "May God watch over the family."           => "May God",
      "Bless everyone who reads this."           => "bless",
      "Thank you all. Amen."                     => "Amen",
      "We ask this in Jesus' name."              => "in Jesus' name",
      "Remember Isaiah 40:31 this week."         => "scripture citation",
      "As Psalm 23 says, she is not alone."      => "scripture citation",
      "Surah 2:286 has been on my heart."        => "scripture citation"
    }.each do |output, label|
      it "flags #{label.inspect} in #{output.inspect}" do
        expect(described_class.found_in(output, "my mum has surgery on the 14th")).to include(label)
      end
    end

    [
      "Please pray for my mum on the 14th.",
      "Please hold her in your prayers.",
      "Please keep her in your devotions this week.",
      "Could people carry this with me for a while?",
      "Our landlord sold the building, so we move on the 30th.",
      "I start the new job 9:30 on Monday.",
      "The Lordship Lane flat is too small now.",
      "Mark 10 years at the print works with me."
    ].each do |output|
      it "leaves #{output.inspect} alone" do
        expect(described_class.found_in(output)).to be_empty
      end
    end

    it "allows a marker the member wrote themselves" do
      input  = "Psalm 23 has been on my mind. God bless every one of you."
      output = "Psalm 23 has been on my mind. God bless all of you who sent a card."
      expect(described_class.found_in(output, input)).to be_empty
    end

    it "still flags a marker the member did not write, next to one they did" do
      input  = "God bless every one of you."
      output = "God bless every one of you. Amen."
      expect(described_class.found_in(output, input)).to eq([ "Amen" ])
    end
  end

  describe ".clean?" do
    it "is true for an ordinary ask and false for a closing prayer" do
      expect(described_class.clean?("Please pray for my sister.")).to be(true)
      expect(described_class.clean?("Please pray for my sister. Amen.")).to be(false)
    end
  end
end
