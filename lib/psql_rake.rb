# frozen_string_literal: true

require 'sequel'
require 'fileutils'
require 'rake_helpers'

require_relative 'psql_rake/dump_file'

class PSQLRake
	include Rake::DSL
	include RakeHelpers

	def initialize(
		db_config,
		pgpass_file: File.expand_path(File.join('~', '.pgpass')),
		dumps_dir: 'db/dumps',
		namespace_name: 'dumps'
	)
		@db_config = db_config
		@db_access = "-U #{@db_config[:user]} -h #{@db_config[:host]}"
		@pgpass_file = pgpass_file
		@dumps_dir = dumps_dir

		@dump_file_class = DumpFile.wrap(@db_config, @dumps_dir)

		desc 'Start PostgreSQL console'
		task :psql do
			psql
		end

		namespace namespace_name do
			desc 'Make DB dump'
			task :create, :format do |_task, args|
				create args
			end

			desc 'Restore DB dump'
			task :restore, :step do |_task, args|
				restore args
			end

			desc 'List DB dumps'
			task :list do
				DumpFile.all.each(&:print)
			end
		end

		alias_task :dumps, 'dumps:list'
		alias_task :dump, 'dumps:create'
		alias_task :restore, 'dumps:restore'
	end

	private

	def update_pgpass
		pgpass_line =
			@db_config
				.fetch_values(:host, :port, :database, :user, :password) { |_key| '*' }
				.join(':')

		pgpass_lines =
			File.exist?(@pgpass_file) ? File.read(@pgpass_file).split($RS) : []

		return if pgpass_lines&.include? pgpass_line

		File.write @pgpass_file, pgpass_lines.push(pgpass_line, nil).join($RS)
		File.chmod(0o600, @pgpass_file)
	end

	def psql
		update_pgpass
		sh "psql #{@db_access} #{@db_config[:database]}"
	end

	def create(args)
		dump_format =
			if args[:format]
				@dump_file_class::DB_DUMP_FORMATS.find do |db_dump_format|
					db_dump_format.start_with? args[:format]
				end
			else
				@dump_file_class::DB_DUMP_FORMATS.first
			end

		update_pgpass

		filename = @dump_file_class.new(format: dump_format).path
		sh "mkdir -p #{@dumps_dir}"
		start_time = Time.now
		sh "pg_dump #{@db_access} -F#{dump_format.chr}" \
			 " #{@db_config[:database]} > #{filename}"
		puts "Done in #{(Time.now - start_time).round(2)} s."
	end

	def restore(args)
		args.with_defaults(step: -1)

		step = Integer(args[:step])

		update_pgpass

		dump_file = @dump_file_class.all[step]

		abort 'Dump file not found' unless dump_file

		if Question.new("Restore #{dump_file} ?", %w[yes no]).answer == 'no'
			abort 'Okay'
		end

		Rake::Task['db:dump'].invoke

		case dump_file.format
		when 'custom'
			sh "pg_restore #{@db_access} -n public -d #{@db_config[:database]}" \
				 " #{dump_file.path} --jobs=4 --clean --if-exists"
		when 'plain'
			Rake::Task['db:drop'].invoke
			Rake::Task['db:create'].invoke
			sh "psql #{@db_access} #{@db_config[:database]} < #{dump_file.path}"
		else
			raise 'Unknown DB dump file format'
		end
	end
end
