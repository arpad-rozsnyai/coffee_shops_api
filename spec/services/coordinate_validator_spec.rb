require "rails_helper"

RSpec.describe CoordinateValidator do
  describe ".call" do
    context "when x is missing" do
      it "is invalid with a can't-be-blank error on x" do
        result = described_class.call(x: nil, y: "5")

        expect(result[:errors]).not_to be_empty
        expect(result[:x]).to be_nil
        expect(result[:errors]).to contain_exactly(
          { attribute: :x, detail: "can't be blank" }
        )
      end
    end

    context "when y is missing" do
      it "is invalid with a can't-be-blank error on y" do
        result = described_class.call(x: "5", y: nil)

        expect(result[:errors]).not_to be_empty
        expect(result[:y]).to be_nil
        expect(result[:errors]).to contain_exactly(
          { attribute: :y, detail: "can't be blank" }
        )
      end
    end

    context "when both x and y are missing" do
      it "reports both attributes" do
        result = described_class.call(x: nil, y: nil)

        expect(result[:errors]).not_to be_empty
        expect(result[:errors]).to contain_exactly(
          { attribute: :x, detail: "can't be blank" },
          { attribute: :y, detail: "can't be blank" }
        )
      end
    end

    context "with blank values" do
      it "treats an empty string as blank" do
        result = described_class.call(x: "", y: "5")

        expect(result[:errors]).not_to be_empty
        expect(result[:errors]).to contain_exactly(
          { attribute: :x, detail: "can't be blank" }
        )
      end

      it "treats a whitespace-only string as blank" do
        result = described_class.call(x: "5", y: "   ")

        expect(result[:errors]).not_to be_empty
        expect(result[:errors]).to contain_exactly(
          { attribute: :y, detail: "can't be blank" }
        )
      end
    end

    context "with non-numeric strings" do
      it "is invalid with an is-not-a-valid-number error" do
        result = described_class.call(x: "abc", y: "5")

        expect(result[:errors]).not_to be_empty
        expect(result[:x]).to be_nil
        expect(result[:errors]).to contain_exactly(
          { attribute: :x, detail: "is not a valid number" }
        )
      end

      it "does not fall back to to_f-style silent coercion (e.g. '12abc')" do
        result = described_class.call(x: "12abc", y: "5")

        expect(result[:errors]).not_to be_empty
        expect(result[:errors]).to contain_exactly(
          { attribute: :x, detail: "is not a valid number" }
        )
      end
    end

    context "with valid integers" do
      it "parses them as floats" do
        result = described_class.call(x: "47", y: "-122")

        expect(result[:errors]).to be_empty
        expect(result[:x]).to eq(47.0)
        expect(result[:y]).to eq(-122.0)
        expect(result[:errors]).to eq([])
      end
    end

    context "with valid decimals" do
      it "parses them as floats" do
        result = described_class.call(x: "47.6", y: "-122.4")

        expect(result[:errors]).to be_empty
        expect(result[:x]).to eq(47.6)
        expect(result[:y]).to eq(-122.4)
      end
    end

    context "with valid negative coordinates" do
      it "accepts negative values for both x and y" do
        result = described_class.call(x: "-1.5", y: "-2.5")

        expect(result[:errors]).to be_empty
        expect(result[:x]).to eq(-1.5)
        expect(result[:y]).to eq(-2.5)
      end
    end
  end
end
