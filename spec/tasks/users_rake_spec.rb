require "rails_helper"
require "rake"

RSpec.describe "users:create rake task" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("users:create")
  end

  let(:task) { Rake::Task["users:create"] }

  before { task.reenable }

  around do |example|
    original = ENV.to_h.slice("name", "email", "password")
    example.run
  ensure
    original.each { |key, value| ENV[key] = value }
  end

  it "creates a user with the given name, email, and password" do
    ENV["name"] = "Jane Doe"
    ENV["email"] = "jane@example.com"
    ENV["password"] = "correct-password"

    expect { task.invoke }.to change(User, :count).by(1)

    user = User.last
    expect(user.name).to eq("Jane Doe")
    expect(user.email).to eq("jane@example.com")
    expect(user.valid_password?("correct-password")).to eq(true)
  end

  it "prints the created user's email and id" do
    ENV["name"] = "Jane Doe"
    ENV["email"] = "jane@example.com"
    ENV["password"] = "correct-password"

    expect { task.invoke }.to output(/Created user jane@example\.com \(id: \d+\)/).to_stdout
  end

  it "exits with an error and creates no user when required fields are missing" do
    ENV["name"] = nil
    ENV["email"] = nil
    ENV["password"] = nil

    expect { task.invoke }.to raise_error(SystemExit)
    expect(User.count).to eq(0)
  end

  it "exits with an error and creates no user when the email is already taken" do
    create(:user, email: "jane@example.com")
    ENV["name"] = "Jane Doe"
    ENV["email"] = "jane@example.com"
    ENV["password"] = "correct-password"

    expect { task.invoke }.to raise_error(SystemExit)
    expect(User.count).to eq(1)
  end
end
