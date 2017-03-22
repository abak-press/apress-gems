require 'bundler'
require 'pty'
require 'uri'
require 'net/http/post/multipart'
require 'apress/changelogger'

module Apress
  module Gems
    class Cli
      GEMS_URL = 'https://gems.railsc.ru/'.freeze

      DEFAULT_OPTIONS = {
        bump: true,
        changelog: true,
        pull: true,
        push: true,
        remote: "origin",
        branch: "master",
        quiet: false,
        source: 'https://gems.railsc.ru/'
      }.freeze

      def initialize(options)
        @options = DEFAULT_OPTIONS.merge(options)
      end

      def changelog
        Apress::ChangeLogger.new.log_changes
        spawn 'git add CHANGELOG.md'
        log 'Changelog generated'
      end

      def bump
        validate_version
        update_version
        changelog if @options[:changelog]

        spawn "git commit -m 'Release #{version}'"

        if @options[:push]
          spawn "git push #{remote} #{branch}"
          log 'Changes pushed to repository'
        end
      end

      def build
        FileUtils.mkdir_p('pkg')

        spawn "gem build -V #{spec_path}"
        built_gem_path = Dir["#{gemspec.name}-*.gem"].sort_by { |f| File.mtime(f) }.last

        FileUtils.mv(built_gem_path, 'pkg')
        log 'Package built'
      end

      def upload
        tarball_name = "#{gemspec.name}-#{version_or_current}.gem"
        upload_gem(source_uri, tarball_name)
      end

      def tag
        tag_name = "v#{version_or_current}"

        spawn "git tag -a -m \"Version #{version_or_current}\" #{tag_name}"
        spawn "git push --tags #{remote}" if @options[:push]

        log "Git tag generated to #{tag_name}"
      end

      def current
        puts find_version
      end

      def exist
        if exist?
          log "Gem already released"
          exit(0)
        else
          log "Gem is not released"
          exit(1)
        end
      end

      def release
        pull_latest if @options[:pull]
        bump if @options[:bump]
        tag
        build
        upload
      end

      private

      def version
        @version ||= @options.fetch(:version)
      end

      def version_or_current
        @version_or_current ||= @options.fetch(:version, find_version)
      end

      def branch
        @branch ||= @options.fetch(:branch)
      end

      def remote
        @remote ||= @options.fetch(:remote)
      end

      def find_version
        Dir['lib/**/version.rb'].each do |file|
          contents = File.read(file)
          return contents.match(/VERSION\s*=\s*(['"])(.*?)\1/m)[2]
        end
      end

      def exist?
        cmd = "gem search #{gemspec.name} --clear-sources -s '#{source_uri}' --exact --quiet -a"
        output = spawn(cmd)
        escaped_version = Regexp.escape(version_or_current)
        !!(output =~ /[( ]#{escaped_version}[,)]/)
      end

      def update_version
        Dir['lib/**/version.rb'].each do |file|
          contents = File.read(file)
          contents.gsub!(/VERSION\s*=\s*(['"])(.*?)\1/m, "VERSION = '#{version}'.freeze")
          File.write(file, contents)
          spawn "git add #{file}"
          log "Version updated to #{version}"
        end
      end

      def source_uri
        return @uri if defined?(@uri)
        source_url = @options.fetch(:source)
        @uri = URI.parse(source_url)
        @uri.userinfo = Bundler.settings[source_url]
        @uri
      end

      def pull_latest
        spawn "git pull #{remote} #{branch}"
        spawn "git fetch --tags #{remote}"
      end

      def validate_version
        fail "New gems should be released with version 0.1.0" if Gem::Version.new(version) < Gem::Version.new("0.1.0")

        return if version == '0.1.0'
        return if Gem::Version.new(version) > Gem::Version.new(find_version)

        fail 'New version less or equal then current version'
      end

      # run +cmd+ in subprocess, redirect its stdout to parent's stdout
      def spawn(cmd)
        log ">> #{cmd}"

        cmd += ' 2>&1'
        output = ""
        PTY.spawn cmd do |r, _w, pid|
          begin
            r.sync
            r.each_char do |chr|
              STDOUT.write(chr) unless @options[:quiet]
              output << chr
            end
          rescue Errno::EIO
            # simply ignoring this
          ensure
            ::Process.wait pid
          end
        end
        abort "#{cmd} failed, exit code #{$? && $?.exitstatus}" unless $? && $?.exitstatus == 0

        output.strip
      end

      def load_gemspec
        return if defined?(@gemspec)
        gemspecs = Dir[File.join(Dir.pwd, '{,*}.gemspec')]
        raise 'Unable to determine name from existing gemspec' unless gemspecs.size == 1
        @spec_path = gemspecs.first
        @gemspec = Bundler.load_gemspec(@spec_path)
      end

      def gemspec
        load_gemspec
        @gemspec
      end

      def spec_path
        load_gemspec
        @spec_path
      end

      def upload_gem(repo_uri, tarball_name)
        repo_uri.path = '/upload'

        log "Start uploading gem #{tarball_name} to #{repo_uri.host}"

        tarball_path = File.join('pkg', tarball_name)

        File.open(tarball_path) do |gem|
          req = Net::HTTP::Post::Multipart.new(repo_uri.path,
                                               'file' => UploadIO.new(gem, 'application/x-tar', tarball_name))

          req.basic_auth(repo_uri.user, repo_uri.password) if repo_uri.user

          res = Net::HTTP.start(repo_uri.host, repo_uri.port, use_ssl: repo_uri.scheme == 'https') do |http|
            http.request(req)
          end

          if [200, 302].include?(res.code.to_i)
            log "#{tarball_name} uploaded successfully"
          else
            $stderr.puts "Cannot upload #{tarball_name}. Response status: #{res.code}"
            exit(1)
          end
        end
      end

      def log(message)
        return if @options[:quiet]
        puts message
      end
    end
  end
end
