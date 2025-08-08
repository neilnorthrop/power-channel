ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Include route helpers for tests
    include Rails.application.routes.url_helpers

    # Add more helper methods to be used by all tests here...

    setup do
      # Ensure resources, actions, skills, and items are available for tests
      # These are typically loaded via fixtures, but if not, they can be created here.
      # For now, we'll rely on fixtures and ensure they are populated.
    end

    # Helper to create records if they don't exist, useful for seeding test data
    # that might not be in fixtures or needs dynamic creation.
    # This method was duplicated, so it's moved here as a single definition.
    def create_if_not_exists(model, records)
      records.each do |attrs|
        model.create(attrs) unless model.exists?(name: attrs[:name])
      end
    end

    # Commenting out specific setup methods as fixtures should handle this.
    # If specific test data is needed beyond fixtures, it should be created
    # directly within the relevant test file's setup block or a dedicated helper.
    #
    # def setup_resources
    #   # Resource.create(...)
    # end
    #
    # def setup_actions
    #   # Action.create(...)
    # end
    #
    # def setup_skills
    #   # Skill.create(...)
    # end
    #
    # def setup_items
    #   # Item.create(...)
    # end

    # Commenting out setup_default_user as Devise's test helpers and fixtures
    # are now used for user management in tests.
    #
    # def setup_default_user
    #   User.create!(
    #     email: "default_test@gmail.com",
    #     password: "password123",
    #     password_confirmation: "password123"
    #   ) unless User.exists?(email: "default_test@gmail.com")
    # end
  end
end
