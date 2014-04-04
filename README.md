# LabdbManager

Command line utility scripts for helping to manage a labdb installation.  Intended to replace the manage.py script in that repository.

## Installation

    $ gem install labdb_manager

## Usage

The gem will install a binary `labdb` that takes command line options for various management tasks.  Prefix most commands with a --dry-run to show the commands that would be run but not actually run them.  This does not work for hostname or secret.

Usage: `labdb [--dry-run] <command>`

Several of the commands assume that they're being run from the root of the labdb installation.

Command should be one of:

- `update`: Updates the labdb installation to the latest stable (master branch) commit.  Makes a backup before doing this.  Precompiles assets after updating.

- `backup`: Dumps the postgres database to a timestamped backup file.

- `hostname`: optionally, supply a hostname on the command line.  If not provided, prompt the user for it.  After requsting or reading from the command line, install into the appropriate file for use by the application.

- `secret`: generate a secure application secret (used for cookie signing) and install it into the appropriate location for use by the application.  The umask will be set to 0600.  Don't share the secret!

- `install`: create the database for production mode (kind of a misnomer at this point since it's not the complete install process...)

- `revert_failure`: if the update fails due to a merge conflict, running this command should bring you back to the last stable state.

- `devserver`: starts the server locally

- `force_update_deps`: updates all dependencies to the latest allowed versions.  It's possible that this could break things.

- `restart`: restart an installation running under control of supervisord.

## Contributing

1. Fork it ( https://github.com/[my-github-username]/labdb_manager/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
