require "securerandom"

require "labdb_manager/version"

COMMAND_PREFIX = "--> "
CONFIRM_PREFIX = "--? "

#git parameters
BR_DEPLOY_STAGING = 'deploy_staging'
BR_DEPLOY = 'deploy'
BR_REMOTE = 'master'
REM_NAME = 'origin'
PROJECT_URL = 'https://github.com/cjfuller/labdb.git'
DEFAULT_REPO_PATH = '~/labdb'
DEFAULT_BACKUP_DIR = '~/backups'
AUTO_MERGE_MESSAGE = '"auto merge by manage.py"'

#database backend
PG_DUMP_PATH = `which pg_dump`.strip

#paths to config files
HOSTNAME_CFG_FILE = 'config/full_hostname.txt'
SECRET_CFG_FILE = 'config/secret_token.txt'

COLORS = {
  green: "\033[92m",
  yellow: "\033[93m",
  red: "\033[91m",
  off: "\033[0m"
}

# define methods on string for each color
class String
  COLORS.each do |c, s|
    define_method c do
      s + self + COLORS[:off]
    end
  end
end

def print_command(cmd)
  ### Print a command being run in a standard format
  puts (COMMAND_PREFIX + cmd).green
end

def confirm(cmd)
  # Ask the user for confirmation of the specified command
  #
  # If confirmation is not given, exit the program immediately without running
  # the command.
  puts (CONFIRM_PREFIX + cmd).yellow
  response = gets
  unless ['yes', 'y'].include? response.downcase then
    exit 0
  end
  cmd
end

SHELL_COMMAND_LIST = []

def queue_command(**kwargs, &bl)
  SHELL_COMMAND_LIST << ShellCommand.new(bl, **kwargs)
end

def run_queued_commands
  SHELL_COMMAND_LIST.each do |c|
    c.call
  end
  SHELL_COMMAND_LIST.clear
end

class ShellCommand
  # A command that gets run in a login shell.

  def self.prepend_login_shell(cmd)
    "/bin/bash --login -c #{cmd}"
  end

  def initialize(cmd_fct, args: [], requires_sudo: false, exit_on_fail: true)
    @cmd_fct = cmd_fct
    @requires_sudo = requires_sudo
    @exit_on_fail = exit_on_fail
    @args = args
  end

  def call
    # Run the command.
    command_string = @cmd_fct.call *@args
    `#{ShellCommand.prepend_login_shell command_string}`
    if $?.exitstatus > 0 and @exit_on_fail
      puts ("Encountered an unresolvable error while running #{command_string}.  " +
        "Please resolve the problem manually and re-run").red
      exit($?.exitstatus)
    end
    $?.exitstatus
  end

  def to_s
    @cmd_fct.call
  end
end

# git commands
def check_for_staging_branch
  # Check (via process return code) if the staging branch already exists.
  #
  # @return 0 if the branch exists, nonzero otherwise

  "git show-ref --verify --quiet refs/heads/#{BR_DEPLOY_STAGING}"
end

def clean_up_staging_branch
  # Delete the staging branch.  Don't check for its existence.
  confirm "git checkout #{BR_DEPLOY} && git branch -d #{BR_DEPLOY_STAGING}"
end

def create_staging_branch
  # Create the staging branch.  Don't check for its existence.
  "git checkout #{BR_DEPLOY} && git branch #{BR_DEPLOY_STAGING}"
end

def fetch_remote_changes
  # Download changes from the central labdb repo set up as a remote.
  #
  # The remote name and branch to download are set up in the constants above.

  "git checkout #{BR_REMOTE} && git pull #{REM_NAME} #{BR_REMOTE}"
end

def stage_changes
  # Merge changes from the downloaded branch into the staging branch.
  #
  # This is where problems should arise if there are merge conflicts.  If this
  # happens and you need to get back to a workable state, you can force the
  # load of the (still unchanged) deploy branch using `manage.py revert-
  # failure`.

  ("git checkout #{BR_DEPLOY_STAGING} && " +
   "git merge -m #{AUTO_MERGE_MESSAGE} #{BR_REMOTE}")
end

def merge_into_production
  # Merge changes from staging into production.
  ("git checkout #{BR_DEPLOY} && " +
   "git merge -m #{AUTO_MERGE_MESSAGE} #{BR_DEPLOY_STAGING}")
end

def revert_merge_failure
  # Revert a merge and go back to production in case conflicts arise.
  "git reset --merge && git checkout #{BR_DEPLOY}"
end

# application commands

def bundle_install
  "bundle install"
end

def bundle_update
  confirm "bundle update"
end

def precompile_assets
  "bundle exec rake assets:precompile"
end

# database commands

def create_backup
  suffix = "_labdb_backup.dump"
  backup_timestring = Time.now.strftime("%Y%m%d_%H%M%S")
  fn = backup_timestring + suffix
  fn_full = File.expand_path(fn, DEFAULT_BACKUP_DIR)
  [PG_DUMP_PATH,
   "-h localhost labdb > #{fn_full}",
   "&&",
   "tar cjf #{fn_full}.tar.bz2 -C {DEFAULT_BACKUP_DIR} {fn}",
   "&&",
   "rm -f #{fn_full}"
   ].join(" ")
end

def create_production_db
  "RAILS_ENV=production bundle exec rake db:setup"
end

# server status commands

def restart_server
  "supervisorctl restart labdb"
end

def run_devserver
  "bundle exec puma --config config/puma.rb"
end

# other commands not using the shell

def set_hostname(hostname: nil)
  if hostname.nil?
    puts 'Please enter the full hostname of the machine.\n' +
      '(i.e. the part that would appear including the https:// ' +
      'in a url but before any other slashes):'
    hostname = gets
    File.open(HOSTNAME_CFG_FILE, 'w') do |f|
      f.write hostname
    end
  end
end

def generate_application_secret
  secret = SecureRandom.hex(64) # 512 bits
  File.open(SECRET_CFG_FILE, 'w') do |f|
    f.write secret
  end
  File.chmod(0600, SECRET_CFG_FILE)
end

# task helpers

def ok
  puts "OK".green
end

# tasks

def update
  queue_command {create_backup}
  if ShellCommand.new(&:check_for_staging_branch).call == 0 then
    queue_command {clean_up_staging_branch}
  end
  queue_command {create_staging_branch}
  queue_command {fetch_remote_changes}
  queue_command {stage_changes}
  queue_command {update_deps_conservative}
  queue_command {precompile_assets}
  queue_command {merge_into_production}
  queue_command {restart_server}
end

def backup
  queue_command {create_backup}
end

def force_update_deps
  queue_command bundle_update
end

def secret
  generate_applicaation_secret
end

def hostname(hostname: nil)
  set_hostname(hostname)
end

def install
  queue_command {create_production_db}
end

def revert_failure
  queue_command {revert_merge_failure}
end

def restart
  queue_command {restart_server}
end

def devserver
  queue_command {run_devserver}
end

def help
end

def run_task(t, args: [])
  send t, *args
  run_queued_commands
  ok
end
