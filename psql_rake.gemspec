# frozen_string_literal: true

require_relative 'lib/psql_rake/version'

Gem::Specification.new do |spec|
	spec.name = 'psql_rake'

	spec.version = PSQLRake::VERSION

	spec.summary = 'Rake tasks for PostgreSQL console and dumps'

	spec.authors = ['Alexander Popov']

	spec.required_ruby_version = '~> 2.3'

	spec.add_runtime_dependency 'rake_helpers', '~> 0.0'

	spec.add_development_dependency 'rubocop', '~> 0.59.2'
end
