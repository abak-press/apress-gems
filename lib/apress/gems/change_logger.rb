# coding: utf-8
# https://github.com/lab2023/katip/blob/develop/lib/katip/change_logger.rb
module Apress
  module Gems
    class ChangeLogger
      COMMIT_URL = '../../commit/'.freeze
      ISSUE_URL = '../../issues/'.freeze
      JIRA_URL = 'https://jira.railsc.ru/browse/'.freeze

      ISSUE_REGEXP = /[A-Z]+\-[0-9]+/
      JIRA_REGEXP = /(?:\s|^)([A-Z]+-[0-9]+)(?=\s|$)/

      GIT_LOG_CMD = %{git log --date=short --pretty=format:" * %ad [%h](#{COMMIT_URL}%h) - __(%an)__ %s"}.freeze
      EXCLUDE_MERGE = %{grep -v -E "Merge (branch|pull)"}.freeze

      # initialize
      #
      # @param [String] file_name with path
      def initialize(file_name = 'CHANGELOG.md', from = nil, to = nil)
        @file_name = file_name
        @tag_from = from
        @tag_to = to
      end

      def log_changes
        return unless git_repository?

        output = parse_change_log
        write_file output unless output.empty?
      end

      private

      def git_repository?
        initialized = `git rev-parse --is-inside-work-tree`.chomp

        if initialized != 'true'
          initialized = false
          puts 'Exiting. Nothing to create log file.'
        end
        initialized
      end

      def write_file(output)
        File.open(@file_name, 'w') do |file|
          file.puts(output)
        end
      end

      def parse_change_log
        output = []

        tags = `git for-each-ref --sort='*authordate' --format='%(tag)' refs/tags | grep -v '^$'#`

        tags = tags.split
        prev_begin = nil

        if (!@tag_from.nil? && !tags.include?(@tag_from)) || (!@tag_to.nil? && !tags.include?(@tag_to))
          show_not_found_message(tags)
          return output
        end

        if !@tag_from.nil? && !@tag_to.nil?
          from = tags.index(@tag_from)
          to = tags.index(@tag_to)
          tags = tags[from..to]
        elsif !@tag_from.nil?
          from = tags.index @tag_from
          prev_begin = tags[from - 1]
          tags = tags[from..-1]
        elsif !@tag_to.nil?
          to = tags.index @tag_to
          tags = tags[0..to]
        end

        tags.reverse!

        output << "\n#### [Current]" if @tag_to.nil?

        previous_tag = ''
        tags.each do |tag|
          current_tag = tag

          output << "\n#### #{previous_tag}" unless previous_tag.empty?

          if !previous_tag.empty? || @tag_to.nil?
            output << `#{GIT_LOG_CMD} "#{current_tag}".."#{previous_tag}" | #{EXCLUDE_MERGE}`
          end

          previous_tag = current_tag
        end

        output << "\n#### #{previous_tag}"

        if prev_begin.nil?
          output << `#{GIT_LOG_CMD} #{previous_tag} | #{EXCLUDE_MERGE}`
        else
          output << `#{GIT_LOG_CMD} "#{prev_begin}".."#{previous_tag}" | #{EXCLUDE_MERGE}`
        end

        output.each do |line|
          line.encode!('utf-8', 'utf-8', invalid: :replace, undef: :replace, replace: '')

          if line.index(ISSUE_REGEXP)
            line.gsub!(ISSUE_REGEXP) { |s| "[#{s}](#{ISSUE_URL}#{s[-(s.length - 1)..-1]})" }
          end

          if line.index(JIRA_REGEXP)
            line.gsub!(JIRA_REGEXP) { |s| "[#{s}](#{JIRA_URL}#{s[-(s.length - 1)..-1]})" }
          end
        end

        output
      end

      def show_not_found_message(tags)
        puts 'Could not find the given tags. Make sure that given tags exist.'
        puts 'Listing found tags:'
        puts tags
      end
    end
  end
end
