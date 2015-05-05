
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
# ==============================================================================#=


class ProjectRepo

  def initialize(given_hash)
    #
    # given_hash should look like this:
    #   {
    #     :repo_name => "name string",
    #     :git_url   => "Git URL string",
    #     :dir_name  => "local directory name string",
    #   }
    #

    # ----------------------------------------------------------------+-
    # A local name for the repository.
    # ----------------------------------------------------------------+-
    @repo_name = given_hash[:repo_name]

    # ----------------------------------------------------------------+-
    # The repo's official "URL".
    # Note: this is a "Git URL", see: http://git-scm.com/docs/git-clone#URLS
    # ----------------------------------------------------------------+-
    @git_url = given_hash[:git_url]

    # ----------------------------------------------------------------+-
    # Local directory name and
    # Full directory path to the local copy of the repo.
    # ----------------------------------------------------------------+-
    @dir_name = nil
    @dir_path  = nil

    if given_hash.has_key?(:dir_name)
      @dir_name = given_hash[:dir_name]
    end

    update_git_status

  end  ### initialize ###

  private # ~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-+-

  def find_repo_dir_path(given_dir_name)
    #
    # Look in the current dir and all parents for
    # a directory whose name matches the given dir name.
    # Set @dir_name and @dir_path accordingly.
    #
    somedir = Dir.pwd

    while(TRUE)
      repopath = somedir + "/#{given_dir_name}"

      if Dir.exists? repopath
        @dir_name  = given_dir_name
        @dir_path  = repopath
        break
      end
      nextdirup = File.dirname(somedir)
      if nextdirup == somedir
        break
      else
        somedir = nextdirup
      end
    end
  end


  def update_git_status
    if @dir_name
      # Try to find the repository using the configured local dir name.
      find_repo_dir_path(@dir_name)
    end

    if @dir_name.nil? and @dir_path.nil?
      # Try to find the repository using the configured repo name.
      find_repo_dir_path(@repo_name)
    end

    if @dir_name.nil? and @dir_path.nil?
      # Try to find the repository using the repo name from the url.
      find_repo_dir_path(File.basename(@git_url))
    end

    if @dir_name.nil? and @dir_path.nil?
      # Use the repo name from the url.
      @dir_name = File.basename(@git_url)
    end

    @is_a_git_repo = false
    if @dir_path and Dir.exists? "#{@dir_path}/.git"
      ### ### puts "UGS: is a git repo"
      @is_a_git_repo = true
    end

    if @is_a_git_repo
      @git_status_lines = ""
      cmd = SystemCommand.new
      cmd << "cd #{@dir_path} && git status "
      ### ### puts "UGS: git status"
      if cmd.run.success?
        @git_status_lines = cmd.stdout
        ### ### puts "UGS: success"
      else
        @git_status_lines = cmd.stderr
        ### ### puts "UGS: failure"
      end
    end
    is_clean?
    is_behind?
    is_ahead?
    on_branch
  end

  public  # ~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-+-

  def to_s
    str =  ''
    str << "------------------------------------------------------------+- \n"
    str << "#{@repo_name} \n"
    str << "------------------------------------------------------------+- \n"
    str << "GIT URL:    #{@git_url} \n"
    str << "DIR NAME:   #{@dir_name} \n"
    str << "DIR PATH:   #{@dir_path} \n"

    if @dir_path
      str << "GIT REPO?   #{@is_a_git_repo} \n"

      if @is_a_git_repo
        str << " \n"
        str << "ON BRANCH:  #{@on_branch} \n"
        str << "BEHIND:     #{@is_behind} \n"
        str << "AHEAD:      #{@is_ahead} \n"
        str << "CLEAN?      #{@is_clean} \n"

        if !@git_status_lines.empty?
          str << "GIT STATUS LINES:  \n"
          @git_status_lines.each_line {|line| str << "    #{line.chomp!} \n"}
        end
      end
    end
    str << "------------------------------------------------------------+- \n"
    str
  end

  def dir_name
    @dir_name
  end

  def has_a_local_dir?
    @dir_path
  end

  def is_a_git_repo?
    @is_a_git_repo
  end

  def is_clean?
    @is_clean = false

    if @is_a_git_repo
      @git_status_lines.each_line do |l|
        l.chomp!
        if l =~ /^.*working directory clean.*$/i then
          @is_clean = true
          break;
        end
      end
    end
    return @is_clean
  end

  def is_behind?
    @is_behind = false

    if @is_a_git_repo
      @git_status_lines.each_line do |l|
        l.chomp!
        if l =~ /^.*your branch is behind.*$/i then
          @is_behind = true
          break;
        end
      end
    end
    return @is_behind
  end

  def is_ahead?
    @is_ahead = false

    if @is_a_git_repo
      @git_status_lines.each_line do |l|
        l.chomp!
        if l =~ /^.*your branch is ahead.*$/i then
          @is_ahead = true
          break;
        end
      end
    end
    return @is_ahead
  end

  def on_branch
    @on_branch = ""

    if @is_a_git_repo
      @on_branch = "UNKNOWN"
      @git_status_lines.each_line do |l|
        l.chomp!
        if l =~ /^.*on branch (\S*)$/i then
          @on_branch = $1
          break;
        end
      end
    end
    return @on_branch
  end

  def fetch(given_dir)
    str = ""
    cmd = SystemCommand.new

    # Clone the repo as needed.
    unless has_a_local_dir?
      cmd << "cd #{given_dir} && git clone #{@git_url} ./#{@dir_name}"
      str << "\n"
      str << "================================================================================#= \n"
      str << "#{@repo_name} - clone \n"
      str << "================================================================================#= \n"
      str << cmd.str + "\n"
      if cmd.run.success?
        str << "Success. \n"
        str << cmd.stdout
      else
        str << "FAILURE! \n"
        str << cmd.stderr
      end
      update_git_status
    end

    # Run the git fetch origin command.
    if is_a_git_repo?
      cmd << "cd #{@dir_path} && git fetch origin"
      str << "\n"
      str << "================================================================================#= \n"
      str << "#{@repo_name} - fetch \n"
      str << "================================================================================#= \n"
      str << cmd.str + "\n"
      if cmd.run.success?
        str << "Success. \n"
        str << cmd.stdout
      else
        str << "FAILURE! \n"
        str << cmd.stderr
      end
      update_git_status
    end

    str
  end

end  ### class: ProjectRepo ###



__END__
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@|@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@|@

puts "    ========================= git status ==========================================="
      ### ### puts "===================================================================="
      ### ### puts cmd.str
      ### ### puts "===================================================================="
        ### ### puts "===================================================================="
        ### ### puts cmd.stdout
        ### ### puts "===================================================================="

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

