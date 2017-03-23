require 'spec_helper'

RSpec.describe Apress::Gems::Cli do
  let(:cli) { described_class.new(options) }

  describe '#changelog' do
    context 'when no options is provided' do
      let(:options) { {} }
      let(:apress_changelogger) { double('Apress::ChangeLogger') }

      before do
        allow(Apress::ChangeLogger). to receive(:new).and_return(apress_changelogger)
      end

      it 'calls Apress::Changelogger' do
        expect(apress_changelogger).to receive(:log_changes).ordered
        expect(cli).to receive(:spawn).with('git add CHANGELOG.md').ordered

        cli.changelog
      end
    end
  end

  describe '#bump' do
    let(:file_version_name) { 'lib/some_namespace/some_gem/version.rb' }
    let!(:file_version) do
      FileUtils.mkdir_p('lib/some_namespace/some_gem')
      File.write file_version_name, <<-VERSION_FILE
        module SomeGemNamespace
          module GemName
            VERSION = '3.0.0'.freeze
          end
        end
      VERSION_FILE
    end

    context 'when version is invalid' do
      let(:options) { {version: '0.0.1'} }

      it 'raises error' do
        expect { cli.bump }.to raise_error(String)
      end

      context 'when version is less then current' do
        let(:options) { {version: '0.2.1'} }
        it 'raises error' do
          expect { cli.bump }.to raise_error(String)
        end
      end
    end

    context 'when versionis valid' do
      context 'when changelog is skiped' do
        let(:options) { {version: '4.0.0', changelog: false} }

        it 'updates version' do
          expect(cli).to receive(:spawn).with("git add /lib/some_namespace/some_gem/version.rb").ordered
          expect(cli).to receive(:spawn).with("git commit -m 'Release 4.0.0'").ordered
          expect(cli).to receive(:spawn).with("git push origin master").ordered
          cli.bump

          expect(File.read(file_version_name)).to include("VERSION = '4.0.0'.freeze\n")
        end
      end

      context 'when push is skiped' do
        let(:options) { {version: '4.0.0', push: false} }

        it 'updates version' do
          expect(cli).to receive(:spawn).with("git add /lib/some_namespace/some_gem/version.rb").ordered
          expect(cli).to receive(:changelog).ordered
          expect(cli).to receive(:spawn).with("git commit -m 'Release 4.0.0'").ordered

          cli.bump

          expect(File.read(file_version_name)).to include("VERSION = '4.0.0'.freeze\n")
        end
      end

      context 'when full generate' do
        let(:options) { {version: '4.0.0'} }

        it 'updates version' do
          expect(cli).to receive(:spawn).with("git add /lib/some_namespace/some_gem/version.rb").ordered
          expect(cli).to receive(:changelog).ordered
          expect(cli).to receive(:spawn).with("git commit -m 'Release 4.0.0'").ordered
          expect(cli).to receive(:spawn).with("git push origin master").ordered
          cli.bump

          expect(File.read(file_version_name)).to include("VERSION = '4.0.0'.freeze\n")
        end
      end
    end
  end

  describe '#build' do
    let!(:gemspec) do
      File.write 'somegem.gemspec', <<-GEMSPEC
        lib = File.expand_path('../lib', __FILE__)

        Gem::Specification.new do |spec|
          spec.name          = 'somegem'
          spec.version       = '3.0.0'
          spec.authors       = ['someone']
          spec.email         = ['someone@example.com']
          spec.summary       = 'somegem description'
          spec.homepage      = 'https://github.com/abak-press/somegem/'
          spec.license       = 'MIT'

          spec.files         = `git ls-files -z`.split("\x0")
          spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
          spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
          spec.require_paths = ['lib']

          spec.metadata['allowed_push_host'] = 'https://gems.railsc.ru'

          spec.add_runtime_dependency 'bundler'
        end
      GEMSPEC
    end

    let(:options) { {version: '3.0.1'} }

    it 'builds gem' do
      expect(cli).to receive(:spawn).with('gem build -V /somegem.gemspec') do
        File.write('somegem-3.0.1.gem', 'new version')
      end

      cli.build

      expect(File.exist?('pkg/somegem-3.0.1.gem')).to be_truthy
    end
  end

  describe '#upload' do
    let!(:gemspec) do
      File.write 'somegem.gemspec', <<-GEMSPEC
        lib = File.expand_path('../lib', __FILE__)

        Gem::Specification.new do |spec|
          spec.name          = 'somegem'
          spec.version       = '0.7.0'
          spec.authors       = ['someone']
          spec.email         = ['someone@example.com']
          spec.summary       = 'somegem description'
          spec.homepage      = 'https://github.com/abak-press/somegem/'
          spec.license       = 'MIT'

          spec.files         = `git ls-files -z`.split("\x0")
          spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
          spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
          spec.require_paths = ['lib']

          spec.metadata['allowed_push_host'] = 'https://gems.example.com/'

          spec.add_runtime_dependency 'bundler'
        end
      GEMSPEC
    end
    let(:options) { {version: '1.0.0', source: 'https://gems.example.com/'} }

    before do
      FileUtils.mkdir_p('pkg')
      File.write('pkg/somegem-1.0.0.gem', 'gem content')
      http = double
      allow(Net::HTTP).to receive(:start).and_yield http
      allow(http).to receive(:request).and_return(http_response)
    end

    context 'when response is ok' do
      let(:http_response) { double(code: 200) }

      it 'executes without error' do
        expect { cli.upload }.to_not raise_error
      end
    end

    context 'when response is failed' do
      let(:http_response) { double(code: 500) }

      it 'raises SystemExit' do
        expect { cli.upload }.to raise_error SystemExit
      end
    end
  end

  describe '#tag' do
    context 'when no version provided' do
      let(:options) { {} }
      let!(:file_version) do
        FileUtils.mkdir_p('lib/some_namespace/some_gem')
        File.write 'lib/some_namespace/some_gem/version.rb', <<-VERSION_FILE
          module SomeGemNamespace
            module GemName
              VERSION = '3.0.0'.freeze
            end
          end
        VERSION_FILE
      end

      it 'reads version file' do
        expect(cli).to receive(:spawn).with('git tag -a -m "Version 3.0.0" v3.0.0').ordered
        expect(cli).to receive(:spawn).with('git push --tags origin').ordered

        cli.tag
      end
    end

    context 'when version argument is provided' do
      let(:options) { {version: '0.2.1'} }

      it 'update tag by argument' do
        expect(cli).to receive(:spawn).with('git tag -a -m "Version 0.2.1" v0.2.1').ordered
        expect(cli).to receive(:spawn).with('git push --tags origin').ordered

        cli.tag
      end
    end
  end

  describe '#current' do
    let(:options) { {} }
    let!(:file_version) do
      FileUtils.mkdir_p('lib/some_namespace/some_gem')
      File.write 'lib/some_namespace/some_gem/version.rb', <<-VERSION_FILE
        module SomeGemNamespace
          module GemName
            VERSION = '3.0.0'.freeze
          end
        end
      VERSION_FILE
    end

    it 'retuns current version' do
      expect { cli.current }.to output("3.0.0\n").to_stdout
    end
  end

  describe '#exist' do
    let!(:gemspec) do
      File.write 'somegem.gemspec', <<-GEMSPEC
        lib = File.expand_path('../lib', __FILE__)

        Gem::Specification.new do |spec|
          spec.name          = 'somegem'
          spec.version       = '0.7.0'
          spec.authors       = ['someone']
          spec.email         = ['someone@example.com']
          spec.summary       = 'somegem description'
          spec.homepage      = 'https://github.com/abak-press/somegem/'
          spec.license       = 'MIT'

          spec.files         = `git ls-files -z`.split("\x0")
          spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
          spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
          spec.require_paths = ['lib']

          spec.metadata['allowed_push_host'] = 'https://gems.example.com/'

          spec.add_runtime_dependency 'bundler'
        end
      GEMSPEC
    end
    let(:options) { {source: 'https://gems.example.com', version: '1.1.0'} }

    context 'when version is exists' do
      it 'exit with code 0' do
        allow(cli).to(
          receive(:spawn).
            with("gem search somegem --clear-sources -s 'https://gems.example.com' --exact --quiet -a").
            and_return('(1.1.0)')
        )
        allow(cli).to receive(:exit).with(0)

        cli.exist

        expect(cli).to(
          have_received(:spawn).
            with("gem search somegem --clear-sources -s 'https://gems.example.com' --exact --quiet -a")
        )
        expect(cli).to have_received(:exit).with(0)
      end
    end

    context 'when version is new' do
      it 'exit with code 1' do
        allow(cli).to(
          receive(:spawn).
            with("gem search somegem --clear-sources -s 'https://gems.example.com' --exact --quiet -a").
            and_return('(1.0.0)')
        )
        allow(cli).to receive(:exit).with(1)

        cli.exist

        expect(cli).to(
          have_received(:spawn).
            with("gem search somegem --clear-sources -s 'https://gems.example.com' --exact --quiet -a")
        )
        expect(cli).to have_received(:exit).with(1)
      end
    end
  end

  describe '#release' do
    context 'when params are default' do
      let(:options) { {version: '1.0.0'} }
      it 'calls methods in right order' do
        expect(cli).to receive(:spawn).with('git pull origin master').ordered
        expect(cli).to receive(:spawn).with('git fetch --tags origin').ordered
        expect(cli).to receive(:bump).ordered
        expect(cli).to receive(:tag).ordered
        expect(cli).to receive(:build).ordered
        expect(cli).to receive(:upload).ordered

        cli.release
      end
    end

    context 'when pull disabled' do
      let(:options) { {version: '1.0.0', pull: false} }
      it 'calls methods in right order' do
        expect(cli).to receive(:bump).ordered
        expect(cli).to receive(:tag).ordered
        expect(cli).to receive(:build).ordered
        expect(cli).to receive(:upload).ordered

        cli.release
      end
    end

    context 'when bump' do
      let(:options) { {version: '1.0.0', bump: false} }
      it 'calls methods in right order' do
        expect(cli).to receive(:spawn).with('git pull origin master').ordered
        expect(cli).to receive(:spawn).with('git fetch --tags origin').ordered
        expect(cli).to receive(:tag).ordered
        expect(cli).to receive(:build).ordered
        expect(cli).to receive(:upload).ordered

        cli.release
      end
    end
  end
end
