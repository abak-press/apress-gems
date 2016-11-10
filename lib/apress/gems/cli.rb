require 'bundler'
require 'pty'
require 'uri'
require 'net/http/post/multipart'
require 'apress/changelogger'

module Apress
  module Gems
    class Cli
      GEMS_URL = 'https://gems.railsc.ru/'.freeze

      def initialize(options)
        @options = options
        load_gemspec
      end

      def changelog
        Apress::ChangeLogger.new.log_changes
        spawn 'git add CHANGELOG.md'
        puts 'CHANGELOG.md generated'
      end

      def update_version
        return if version == '0.0.1'

        Dir['lib/**/version.rb'].each do |file|
          contents = File.read(file)
          contents.gsub!(/VERSION\s*=\s*(['"])(.*?)\1/m, "VERSION = '#{version}'")
          File.write(file, contents)
          spawn "git add #{file}"
        end
        puts "VERSION updated to #{version}"
      end

      def build
        FileUtils.mkdir_p('pkg')

        spawn "gem build -V #{@spec_path}"
        built_gem_path = Dir["#{@gemspec.name}-*.gem"].sort_by { |f| File.mtime(f) }.last

        FileUtils.mv(built_gem_path, 'pkg')
        puts 'Package built'
      end

      def upload
        tarball_name = "#{@gemspec.name}-#{version}.gem"
        upload_gem(upload_uri, tarball_name)
      end

      def tag
        tag_name = "v#{version}"
        spawn "git tag -a -m \"Version #{version}\" #{tag_name}"
        spawn 'git push --tags upstream'
        puts "Git tag generated to #{tag_name}"
      end

      def current_version
        puts "Current version is #{find_version}"
      end

      def release
        validate_version
        check_git

        changelog
        update_version
        commit
        tag
        build
        upload
      end

      def public_release
        validate_version
        check_git

        changelog
        update_version
        commit
        tag
        build
        `rake release`
      end

      private

      def version
        @version ||= @options.fetch(:version)
      end

      def branch
        @branch ||= @options.fetch(:branch, 'master')
      end

      def find_version
        Dir['lib/**/version.rb'].each do |file|
          contents = File.read(file)
          return contents.match(/VERSION\s*=\s*(['"])(.*?)\1/m)[2]
        end
      end

      def upload_uri
        uri = URI.parse(GEMS_URL)
        uri.userinfo = Bundler.settings[GEMS_URL]
        uri
      end

      def check_git
        `git rev-parse --abbrev-ref HEAD`.chomp.strip == branch || abort("Can be released only from `#{branch}` branch")
        `git remote | grep upstream`.chomp.strip == 'upstream' || abort('Can be released only with `upstream` remote')
        spawn "git pull upstream #{branch}"
        spawn 'git fetch --tags upstream'
      end

      def commit
        puts 'Commit and push changes'
        spawn "git diff --cached --exit-code > /dev/null || git commit -m \"Release #{version}\" || echo -n"
        spawn "git push upstream #{branch}"
      end

      def validate_version
        fail "New gems should be released with version 0.1.0" if Gem::Version.new(version) < Gem::Version.new("0.1.0")

        return if version == '0.1.0'
        return if Gem::Version.new(version) > Gem::Version.new(find_version)

        fail 'New version less then current version'
      end

      # run +cmd+ in subprocess, redirect its stdout to parent's stdout
      def spawn(cmd)
        puts ">> #{cmd}"

        cmd += ' 2>&1'
        PTY.spawn cmd do |r, _w, pid|
          begin
            r.sync
            r.each_char { |chr| STDOUT.write(chr) }
          rescue Errno::EIO
            # simply ignoring this
          ensure
            ::Process.wait pid
          end
        end
        abort "#{cmd} failed, exit code #{$? && $?.exitstatus}" unless $? && $?.exitstatus == 0
      end

      def load_gemspec
        gemspecs = Dir[File.join(Dir.pwd, '{,*}.gemspec')]
        raise 'Unable to determine name from existing gemspec' unless gemspecs.size == 1
        @spec_path = gemspecs.first
        @gemspec = Bundler.load_gemspec(@spec_path)
      end

      def upload_gem(repo_uri, tarball_name)
        repo_uri.path = '/upload'

        puts "Start uploading gem #{tarball_name} to #{repo_uri.host}"

        tarball_path = File.join('pkg', tarball_name)

        File.open(tarball_path) do |gem|
          req = Net::HTTP::Post::Multipart.new(repo_uri.path,
                                               'file' => UploadIO.new(gem, 'application/x-tar', tarball_name))

          req.basic_auth(repo_uri.user, repo_uri.password) if repo_uri.user

          res = Net::HTTP.start(repo_uri.host, repo_uri.port, use_ssl: repo_uri.scheme == 'https') do |http|
            http.request(req)
          end

          if [200, 302].include?(res.code.to_i)
            puts "#{tarball_name} uploaded successfully"
          else
            $stderr.puts "Cannot upload #{tarball_name}. Response status: #{res.code}"
            exit(1)
          end
        end
      end
    end
  end
end
