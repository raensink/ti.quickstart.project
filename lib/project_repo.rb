
# ==============================================================================#=
# FILE:
#   project_repo.rb
#
# DESCRIPTION:
#   A helper class for managing github repositories.
#   """""""""""""""""""""""""""""""""""""""""
#   """""""""""""""""""""""""""""""""""""""""
#   """""""""""""""""""""""""""""""""""""""""
#   """""""""""""""""""""""""""""""""""""""""
#
# DEPENDENCIES:
#   """""""""""""""""""""""""""""""""""""""""
#   """""""""""""""""""""""""""""""""""""""""
#   """""""""""""""""""""""""""""""""""""""""
#   """""""""""""""""""""""""""""""""""""""""
# ==============================================================================#=


class ProjectRepo

  def initialize(repo_hash)
    #
    # repo_hash should look like this:
    # {
    #   :name      => name_string,
    #   :local_dir => dir_name_string,
    #   :url       => url_string,
    # }
    #
  end
end


__END__
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@|@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@|@

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@|@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@|@

================================================================================================#=
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+~
------------------------------------------------------------------------------------------------+-
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@|@
=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+#+
=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-#-
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#=
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=+=

require 'json'
require 'yaml'
require 'tmpdir'
require 'lib/system_command'
require 'lib/vagrant_version_provider'

class VagrantBox

  # Full path to the location on the server where boxes are stored.
  URLPATH_BOXES = "vagrant_boxes"
  DIRPATH_BOXES = "/var/www/" + URLPATH_BOXES

  # Name of the metadata file.
  FILENAME_METADATA = 'metadata.json'

  attr_accessor :box_description

  def initialize(
    box_name,
    server_domain_name,
    server_user_name )

    # A mechanism for running local system commands.
    @cmd = SystemCommand.new

    # A relative path name that identifies this box.
    @box_name = box_name
    @box_description = 'default description'

    # Domain name of the server where this box is stored.
    @server_domain_name = server_domain_name

    # User name on the server; assumes ssl access has been configured.
    @user_at_host = "#{server_user_name}@#{server_domain_name}"

    # Full file path to the remote metadata on the catalog server.
    @filepath_remote_metadata = "#{DIRPATH_BOXES}/#{@box_name}/#{FILENAME_METADATA}"

    # URL to the remote metadata file on the catalog server.
    @urlpath_remote_metadata = "http://#{@server_domain_name}/#{URLPATH_BOXES}/#{@box_name}/#{FILENAME_METADATA}"

    @metadata = nil

    @valid_server_domain_name = false
    check_server_domain_name()

    update_metadata_using_remote_catalog() if exists_in_catalog?
  end

  private # ~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-+-

  def check_server_domain_name()
    @cmd.clr
    @cmd << "host #{@server_domain_name} "
    puts "command: " + @cmd.str
    if @cmd.run.success?
      puts "#{@server_domain_name} is valid. "
      @valid_server_domain_name = true
      return true
    else
      puts "#{@server_domain_name} is not a valid server name "
      puts "    exit status: %d" % @cmd.exit_status
      puts "    command stdout: " + @cmd.stdout
      puts "    command stderr: " + @cmd.stderr
      return false
    end
  end

  def update_metadata_using_remote_catalog()
    @metadata = nil
    @metadata = get_metadata_from_remote_catalog()
    update_metadata_with_numeric_version_values()
  end

  def get_metadata_from_remote_catalog()
    metadata = nil
    Dir.mktmpdir do |tmpdir|
      filepath_local = "#{tmpdir}/#{FILENAME_METADATA}"
      if(copy_file_from_remote(@filepath_remote_metadata, filepath_local))
        metadata = JSON.load(File.open(filepath_local))
      else
        puts "Downloaded no metadata from remote catalog."
      end
    end
    return metadata
  end

  def replace_metadata_in_remote_catalog()
    successful_operation = false

    Dir.mktmpdir do |tmpdir|
      filepath_local = "#{tmpdir}/#{FILENAME_METADATA}"

      # Write current metadata to local JSON file.
      File.open(filepath_local, 'w') { |fh| fh.write JSON.pretty_generate(@metadata) }

      # Upload to catalog server.
      if (copy_file_to_remote(filepath_local, @filepath_remote_metadata))
        update_metadata_using_remote_catalog()
        successful_operation = true
      else
        puts "Failed to copy metadata to remote catalog!"
      end
    end
    return successful_operation
  end

  def update_metadata_with_numeric_version_values
    if @metadata and @metadata.has_key?('versions')
      @metadata['versions'].each do |ver_hash|
        # Version string is major.minor.patch
        # Convert to a numeric value for better sorting of latest.
        num_list = ver_hash['version'].split('.')
        ver_hash['version_number']  = num_list[2].to_i  # patch
        ver_hash['version_number'] += 1000 * num_list[1].to_i  # minor
        ver_hash['version_number'] += 1000000 * num_list[0].to_i  # major
      end
    end
  end

  def copy_file_from_remote(remote_src_path, local_dst_path)
    #
    # Uses scp to copy from remote source to local destination.
    # Assumes ssh access has already been setup for the given user.
    # Returns true/false success indication.
    #
    unless @valid_server_domain_name
      puts "Invalid server domain name."
      return false
    end
    @cmd.clr
    @cmd << "scp -Bqv "   # batch mode, quite
    @cmd << "#{@user_at_host}:#{remote_src_path} "
    @cmd << "#{local_dst_path} "
    puts "\nThis command will take a few seconds... "
    puts "command: " + @cmd.str
    if @cmd.run.success?
      puts "Success."
      return true
    else
      puts "FAILURE!"
      puts "    exit status: %d" % @cmd.exit_status
      puts "    command stdout: " + @cmd.stdout
      puts "    command stderr: " + @cmd.stderr
      return false
    end
  end

  def copy_file_to_remote(local_src_path, remote_dst_path)
    # Uses scp to copy from local source to remote destination.
    # Assumes ssh access has already been setup.
    # Returns true/false success indication.
    #
    unless @valid_server_domain_name
      puts "Invalid server domain name."
      return false
    end
    @cmd.clr
    @cmd << "scp -Bqv "   # batch mode, quite
    @cmd << "#{local_src_path} "
    @cmd << "#{@user_at_host}:#{remote_dst_path} "
    puts "\nThis command may take a while... "
    puts "command: " + @cmd.str
    if @cmd.run.success?
      puts "Success."
      return true
    else
      puts "FAILURE!"
      puts "    exit status: %d" % @cmd.exit_status
      puts "    command stdout: " + @cmd.stdout
      puts "    command stderr: " + @cmd.stderr
      return false
    end
  end

  def upload_boxfile_to_remote_catalog(local_src_path, boxfile_relativepath)

    dst_path = "#{DIRPATH_BOXES}/#{boxfile_relativepath}"

    unless (copy_file_to_remote(local_src_path, dst_path))
      puts "Failed to copy boxfile to remote catalog!"
      return false
    end
    return true
  end

  def get_given_version_from_metadata(given_string)
    requested_version_hash = nil
    if @metadata and @metadata.has_key?('versions')
      @metadata['versions'].each do |ver_hash|
        if (ver_hash['version'].eql? given_string)
          requested_version_hash = ver_hash
        end
      end
    end
    return requested_version_hash
  end

  public  # ~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-+-

  def to_s
    str  = "VagrantBox: \n"
    str += "    box_name:        #{@box_name} \n"
    str += "    box_description: #{@box_description} \n"
    str += "    user_at_host:    #{@user_at_host} \n"
    str += "    filepath_remote_metadata: #{@filepath_remote_metadata} \n"
    str += "    urlpath_remote_metadata:  #{@urlpath_remote_metadata} \n"
    str += "    valid_server_domain_name: #{@valid_server_domain_name} \n"
    str += @metadata.to_yaml
  end

  def exists_in_catalog?()
    unless @valid_server_domain_name
      puts "Invalid server domain name."
      return false
    end
    @cmd.clr
    @cmd << "ssh -q #{@user_at_host} "
    @cmd << "'if [ -f #{@filepath_remote_metadata} ]; then echo \"TRUE\"; else echo \"FALSE\"; fi;'"
    puts
    puts "Checking for metadata in catalog."
    puts "command: " + @cmd.str
    @cmd.run
    if @cmd.stdout.chomp.eql? "TRUE"
      puts "Found metadata."
      return true
    else
      puts "No metadata found."
      return false
    end
  end

  def box_url
    # The URL to the metadata file.
    return @urlpath_remote_metadata
  end

  def add_box_to_catalog()
    # --------------------------------------------------------------+-
    # create dir on catalog server
    # --------------------------------------------------------------+-
    remote_dir = File.dirname(@filepath_remote_metadata)
    puts
    puts "Creating remote directory: #{remote_dir}"
    unless @valid_server_domain_name
      puts "Invalid server domain name."
      return false
    end
    @cmd.clr
    @cmd << "ssh #{@user_at_host} "
    @cmd << "'mkdir -p #{remote_dir}'"
    unless @cmd.run.success?
      puts "Failed to create remote directory."
      puts "command: " + @cmd.str
      puts @cmd.stderr
      return false
    end

    # --------------------------------------------------------------+-
    # Create metadata content
    # --------------------------------------------------------------+-
    @metadata = {}
    @metadata['name'] = @box_name
    @metadata['description'] = @box_description
    @metadata['versions'] = []
    puts
    puts "metadata after add box to catalog"
    puts "metadata: #{@metadata.to_yaml}"

    # --------------------------------------------------------------+-
    # upload metadata
    # --------------------------------------------------------------+-
    puts
    puts "Uploading metadata."
    unless replace_metadata_in_remote_catalog
      puts "Failed to upload metadata."
      return false
    end
    return true
  end

  def remove_box_from_catalog()
    # --------------------------------------------------------------+-
    # remove dir on catalog server
    # --------------------------------------------------------------+-
    remote_dir = File.dirname(@filepath_remote_metadata)
    puts
    puts "Removing remote directory: #{remote_dir}"
    unless @valid_server_domain_name
      puts "Invalid server domain name."
      return false
    end
    @cmd.clr
    @cmd << "ssh #{@user_at_host} "
    @cmd << "'rm -rf #{remote_dir}'"
    if @cmd.run.success?
      @metadata = nil
    else
      puts "Failed to remove remote directory."
      puts "command: " + @cmd.str
      puts @cmd.stderr
      return false
    end
    return true
  end

  def get_box_name_from_metadata()
    name = nil
    unless @metadata.nil?
      name = @metadata['name']
    end
    return name
  end

  def get_box_description_from_metadata()
    desc = nil
    unless @metadata.nil?
      desc = @metadata['description']
    end
    return desc
  end

  def get_latest_version_provider(given_provider)
    # returns a VersionProvider object.
    # returns nil when not found
    #
    # The 'versions' list should look like this in yaml:
    #     @metadata['versions']
    #     ---
    #     - version: 0.2.0
    #       providers:
    #       - name: virtualbox
    #         url: http://al2-bridge-builder10.spindance.inc/vagrant/mint17/mint17_0.1.0.box
    #         checksum_type: sha1
    #         checksum: 7b9cf07a0f8a8878104aff82f29ae7420047290c
    #     - version: 0.1.0
    #       providers:
    #       - name: virtualbox
    #         url: http://al2-bridge-builder10.spindance.inc/vagrant/mint17/mint17_0.1.0.box
    #         checksum_type: sha1
    #         checksum: 7b9cf07a0f8a8878104aff82f29ae7420047290c
    #
    latest_version_provider_object = nil

    if @metadata and @metadata.has_key?('versions') and not @metadata['versions'].empty?

      latest_version_hash = @metadata['versions'].sort_by{|hsh| hsh['version_number']}[-1]
      latest_version_string = latest_version_hash['version']

      latest_version_hash['providers'].each do | provider_hash |
        if (provider_hash['name'].eql? given_provider)

          latest_version_provider_object = VagrantVersionProvider.new(
            self,
            latest_version_string,
            provider_hash['name']
          )
          latest_version_provider_object.checksum_type = provider_hash['checksum_type']
          latest_version_provider_object.checksum = provider_hash['checksum']
        end
      end
    end
    return latest_version_provider_object
  end

  def add_version_provider_to_catalog(given_vpo)
    #
    # Given a new version provider object,
    # add its information to the metadata in the catalog.
    # Then upload the actual boxfile.
    #
    new_version_string = given_vpo.version_string
    if (get_given_version_from_metadata(new_version_string))
      puts "Version #{new_version_string} already exists"
      return false
    end

    new_version = {}
    new_version['version'] = new_version_string
    new_version['providers'] = []

    new_provider = {}
    new_provider['name']          = given_vpo.provider_type
    new_provider['checksum']      = given_vpo.checksum
    new_provider['checksum_type'] = given_vpo.checksum_type

    new_provider['url']  = "http://#{@server_domain_name}/#{URLPATH_BOXES}/"
    new_provider['url'] += given_vpo.boxfile_relativepath

    new_version['providers'] << new_provider

    @metadata['versions'] << new_version

    puts
    puts "metadata after add new version"
    puts "metadata: #{@metadata.to_yaml}"

    # --------------------------------------------------------------+-
    # upload metadata and box file
    # --------------------------------------------------------------+-
    unless replace_metadata_in_remote_catalog
      puts "Failed to upload metadata for new version provider."
      return false
    end
    unless upload_boxfile_to_remote_catalog(given_vpo.boxfile_localfilepath, given_vpo.boxfile_relativepath)
      puts "Failed to upload boxfile."
      return false
    end

    return true
  end

end ### class VagrantBox ###


__END__
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@|@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@|@

dir = Dir.mktmpdir
begin
  # use the directory...
  open("#{dir}/foo", "w") { ... }
ensure
  # remove the directory.
  FileUtils.remove_entry dir
end

Dir.mktmpdir {|dir|
  # use the directory...
  open("#{dir}/foo", "w") { ... }
}



