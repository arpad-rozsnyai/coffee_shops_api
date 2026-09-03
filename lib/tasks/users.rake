namespace :users do
  desc "Create a new user: bin/rails users:create name='Jane Doe' email=jane@example.com password=secret123"
  task create: :environment do
    user = User.new(name: ENV["name"], email: ENV["email"], password: ENV["password"])

    if user.save
      puts "Created user #{user.email} (id: #{user.id})"
    else
      warn "Failed to create user: #{user.errors.full_messages.join(', ')}"
      exit 1
    end
  end
end
