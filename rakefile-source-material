
# ==============================================================================================#=
# FILE:
#   rakefile.rb
#
# DESCRIPTION:
#   rake fetch
#       Do 'git fetch origin' in each repository in this directory.
#
#   rake
#   rake status
#       Do 'git status' in each repository in this directory.
#
#   works with git version 1.7.9.5
# ==============================================================================================#=
require 'rake'


$SEP1 = '================================================================================================#='
$SEP2 = '--------------------------------------------------------------------------------+-'


$THIS_DIR_PATH = File.expand_path('../..', __FILE__)

# --------------------------------------------------------------+-
# --------------------------------------------------------------+-
$RepoData = {}


# --------------------------------------------------------------+-
# showRepoData()
# --------------------------------------------------------------+-
def showRepoData
    puts
    puts
    puts Dir.pwd

    printFormat = "%48s: %-9s %6s/%5s %s \n"
    countRepos = 0

    puts $SEP1
    printf printFormat,
        "Repo Name",
        "Clean?",
        "Behind",
        "Ahead",
        "Branch"
    puts $SEP1

    $RepoData.keys.sort.each do |repoName|
        printf printFormat,
            repoName,
            $RepoData[repoName][:isClean],
            $RepoData[repoName][:isBehind],
            $RepoData[repoName][:isAhead],
            $RepoData[repoName][:branchName]
        countRepos += 1
        puts if (countRepos % 4 == 0)
    end
end


# --------------------------------------------------------------+-
# dumpRepoData()
# --------------------------------------------------------------+-
def dumpRepoData
    puts
    puts $SEP1
    puts "$RepoData"
    puts $SEP1
    puts $RepoData.inspect
    puts
end


# --------------------------------------------------------------+-
# getRepoList()
#
# Return list of git repositories in current directory.
# Also initializes the RepoData hash with same.
# To be a repo, it must be a directory and
# it must contain a .git file.
# --------------------------------------------------------------+-
def getRepoList
    repoList = []

    FileList.new('./*').each do |filePath|
        if File.directory?(filePath)
            if File.exist?(filePath + '/.git')
                repoList << filePath
                repoName = File.basename(filePath)
                $RepoData[repoName] = {:path => filePath}
            end
        end
    end

    return repoList
end


# --------------------------------------------------------------+-
# setBranchName()
# --------------------------------------------------------------+-
def setBranchName(repoName)
    $RepoData[repoName][:branchName] = "UNKNOWN"
    $RepoData[repoName][:statusLines].each_line do |l|
        l.chomp!
        if l =~ /^.*on branch (\S*)$/i then
            $RepoData[repoName][:branchName] = $1
            break;
        end
    end
end


# --------------------------------------------------------------+-
# setIsClean()
# --------------------------------------------------------------+-
def setIsClean(repoName)
    $RepoData[repoName][:isClean] = "NOT-CLEAN"
    $RepoData[repoName][:statusLines].each_line do |l|
        l.chomp!
        if l =~ /^.*working directory clean.*$/i then
            $RepoData[repoName][:isClean] = "clean"
            break;
        end
    end
end


# --------------------------------------------------------------+-
# setIsBehind()
# --------------------------------------------------------------+-
def setIsBehind(repoName)
    $RepoData[repoName][:isBehind] = ""
    $RepoData[repoName][:statusLines].each_line do |l|
        l.chomp!
        if l =~ /^.*your branch is behind.*$/i then
            $RepoData[repoName][:isBehind] = "Behind"
            break;
        end
    end
end


# --------------------------------------------------------------+-
# setIsAhead()
# --------------------------------------------------------------+-
def setIsAhead(repoName)
    $RepoData[repoName][:isAhead] = ""
    $RepoData[repoName][:statusLines].each_line do |l|
        l.chomp!
        if l =~ /^.*your branch is ahead.*$/i then
            $RepoData[repoName][:isAhead] = "AHEAD"
            break;
        end
    end
end


# --------------------------------------------------------------+-
# target: default
# --------------------------------------------------------------+-
task :default => [:status]


# --------------------------------------------------------------+-
# target: fetch
# --------------------------------------------------------------+-
desc "#{$THIS_DIR_PATH}: git fetch origin"
task :fetch do

    getRepoList().each do |repoName|
        puts
        puts $SEP2
        puts File.basename(repoName)
        puts $SEP2
        verbose(false) do
            cmd  = "cd #{repoName} && "
            cmd += "git fetch origin "
            sh cmd
        end
    end
end


# --------------------------------------------------------------+-
# target: integration
# --------------------------------------------------------------+-
desc "#{$THIS_DIR_PATH}: git checkout integration"
task :integration do

    getRepoList().each do |repoName|
        puts
        puts $SEP2
        puts File.basename(repoName)
        puts $SEP2
        verbose(false) do
            cmd  = "cd #{repoName} && "
            cmd += "git checkout integration "
            sh cmd
        end
    end
end


# --------------------------------------------------------------+-
# target: status
# --------------------------------------------------------------+-
desc "Status of each repository in: #{$THIS_DIR_PATH}. (default task)"
task :status do
    lines = []
    getRepoList().each do |repoPath|
        repoName = File.basename(repoPath)
        puts
        puts $SEP2
        puts repoName
        puts $SEP2
        verbose(false) do
            cmd  = "cd #{repoName} && "
            cmd += "git status "
            lines = %x|#{cmd}|
            $RepoData[repoName][:statusLines] = lines;
        end
        lines.each_line do |l|
            l.chomp!
            puts "#{l}"
        end
        setIsClean(repoName)
        setIsBehind(repoName)
        setIsAhead(repoName)
        setBranchName(repoName)
    end
    showRepoData()

end ### task: status ###




__END__
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@|@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@|@


