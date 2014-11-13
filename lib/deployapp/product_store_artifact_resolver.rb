require 'rubygems'
require 'deployapp/namespace'
require 'deployapp/util/log'
require 'net/ssh'
require 'net/scp'
require 'time'

class TooManyArtifacts < Exception
end

class ArtifactNotFound < Exception
end

class DeployApp::ProductStoreArtifactResolver
  include DeployApp::Util::Log
  def initialize(args)
    @artifacts_dir = args[:artifacts_dir]
    @maxartifacts = 5
    @ssh_key_location = args[:ssh_key_location]
    @latest_jar = args[:latest_jar]
    @ssh_address = "productstore.net.local"
    @debug = false
  end

  def can_resolve(coords)
    artifact_file="#{@artifacts_dir}/#{coords.string}"
    return true if File.exist?(artifact_file)
    return count_artifacts(coords) > 0
  end

  def resolve(coords)
    logger.info("resolving #{coords.string}")
    artifact_file="#{@artifacts_dir}/#{coords.string}"

    if File.exist?(artifact_file)
      logger.info("using artifact #{coords.string} from cache")
      FileUtils.touch(artifact_file)
    else
      logger.info("downloading artifact #{coords.string} from #{@ssh_address}")
      candidate_count = count_artifacts(coords)
      raise TooManyArtifacts.new("got #{artifact}") if candidate_count > 1
      raise ArtifactNotFound.new("could not find artifact with Coords #{coords.string}") if candidate_count == 0

      start = Time.new()
      Net::SCP.start(@ssh_address, "productstore", :keys=>[@ssh_key_location], :config=>false, :user_known_hosts_file=>[]) do |scp|
        d = scp.download("/opt/ProductStore/#{coords.name}/#{artifact}", artifact_file)
        d.wait
      end
      elapsed_time = Time.new() - start
      logger.info("downloaded artifact #{coords.string} #{elapsed_time} seconds")
    end

    self.cleanOldArtifacts
    file = File.new(artifact_file)
    FileUtils.ln_sf(file.path,  @latest_jar)

    logger.info("#{coords.string} resolved successfully")
    return file
  end

  def cleanOldArtifacts()
    files = Dir.glob("#{@artifacts_dir}/*.jar")
    sorted = files.sort_by {|filename| File.mtime("#{filename}") }
    if (sorted.size()>@maxartifacts)
      sorted[0..files.size()-@maxartifacts-1].each do |f|
        print "removing old artifact #{f}\n";
        File.delete f
      end
    end
  end

  def count_candidates(coords)
    artifact=""
    verbose = @debug ? :debug : :error
    Net::SSH.start( @ssh_address, "productstore", :keys=>[@ssh_key_location], :verbose => verbose, :config=>false, :user_known_hosts_file=>[])  do|ssh|
      cmd = "ls /opt/ProductStore/#{coords.name}/ | grep .*-#{coords.version}.*#{coords.type}"
      ssh.exec!(cmd) do |channel,stream,data|
        artifact << data.chomp if stream == :stdout
      end
    end

    return 2 if artifact =~ /\n/
    return 0 if artifact == ""
    return 1
  end

  private :count_candidates
end

