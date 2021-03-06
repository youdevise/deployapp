require 'rubygems'
require 'rake'
begin # Ruby 1.8 vs 1.9 fuckery
  require 'rake/rdoctask'
rescue Exception
  require 'rdoc/task'
end
require 'fileutils'
require 'rspec/core/rake_task'
require 'ci/reporter/rake/rspec'

class Project
  def initialize(args)
    @name = args[:name]
    @description = args[:description]
    @version = args[:version]
  end

  attr_reader :name

  attr_reader :description

  attr_reader :version
end

@project = Project.new(
  :name => 'deploytool',
  :description => 'deployment tool',
  :version => "1.0.#{ENV['BUILD_NUMBER']}"
)

task :default do
  sh 'rake -s -T'
end

desc 'Remove build directory, etc.'
task :clean do
  FileUtils.rmtree('build')
  FileUtils.rmtree('config')
  if File.exists?('app_under_test.properties')
    FileUtils.rm('app_under_test.properties')
  end
end

desc 'Make build directories'
task :setup do
  File.open('app_under_test.properties', 'w') do |f|
    f.write('application=JavaHttpRef\n')
    f.write("version=1.0.18\n")
    f.write("type=jar\n")
  end
  FileUtils.makedirs('build/db')
  FileUtils.makedirs('build/artifacts')
  FileUtils.cp('JavaHttpRef-1.0.18.jar', 'build/artifacts')
  FileUtils.makedirs('config/JavaHttpRef')
  File.open('config/JavaHttpRef/config.properties', 'w') do |f|
    f.write("port=2003\n")
  end
end

desc 'Create Debian package'
task :package do
  require 'rubygems'
  require 'fpm'
  require 'fpm/program'
  FileUtils.mkdir_p('build/package/opt/deploytool/')
  FileUtils.cp_r('lib', 'build/package/opt/deploytool/')
  FileUtils.cp_r('bin', 'build/package/opt/deploytool/')

  arguments = [
    '-p', "build/#{@project.name}_#{@project.version}.deb",
    '-n', "#{@project.name}",
    '-v', "#{@project.version}",
    '-m', 'David Ellis <david.ellis@timgroup.com>',
    '-d', 'libnet-ssh2-ruby',
    '-d', 'libnet-scp-ruby',
    '-a', 'all',
    '-t', 'deb',
    '-s', 'dir',
    '--post-install', 'postinst.sh',
    '--description', "#{@project.description}",
    '--url', 'http://seleniumhq.org',
    '-C', 'build/package'
  ]

  fail 'problem creating debian package ' unless FPM::Program.new.run(arguments) == 0
end

desc 'Run specs'
RSpec::Core::RakeTask.new(:spec => ['ci:setup:rspec']) do |_t|
end
task :spec => [:setup]

desc 'Setup, package, test, and upload'
task :build  => [:setup, :package, :spec]

desc 'Run lint (Rubocop)'
task :lint do
  sh 'rubocop'
end
