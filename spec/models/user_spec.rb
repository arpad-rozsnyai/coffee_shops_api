require "rails_helper"

RSpec.describe User, type: :model do
  it "is valid with a name, email, and password" do
    expect(build(:user)).to be_valid
  end

  it "requires a name" do
    user = build(:user, name: nil)

    expect(user).not_to be_valid
    expect(user.errors[:name]).to be_present
  end

  it "requires a unique email" do
    create(:user, email: "taken@example.com")
    user = build(:user, email: "taken@example.com")

    expect(user).not_to be_valid
    expect(user.errors[:email]).to be_present
  end

  it "requires a password" do
    user = build(:user, password: nil)

    expect(user).not_to be_valid
    expect(user.errors[:password]).to be_present
  end

  describe "#valid_password?" do
    it "returns true for the correct password" do
      user = create(:user, password: "correct-password")

      expect(user.valid_password?("correct-password")).to eq(true)
    end

    it "returns false for an incorrect password" do
      user = create(:user, password: "correct-password")

      expect(user.valid_password?("wrong-password")).to eq(false)
    end
  end
end
