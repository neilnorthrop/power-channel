# frozen_string_literal: true

require "rails/command"

module Rails
  module Command
    class RubocopCommand < Base # :nodoc:
      desc "rubocop [options]", "Run RuboCop linter"

      def perform(*args)
        require "rubocop"
        exit(::RuboCop::CLI.new.run(args))
      rescue LoadError
        say "RuboCop is not installed. Add it to your Gemfile and bundle install.", :red
        exit(1)
      end
    end
  end
end
