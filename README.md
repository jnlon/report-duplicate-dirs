# report-duplicate-dirs

Display paths to duplicate directories in the filesystem

Directories are compared to each other based on a "checksum" defined by

* The total cumulative size of every file in a directory
* A sorted list of every file beneath a directory

If these stats are equivalent between directories, they are considered the same
directory and their paths will be printed to stdout

## Usage

`guile ./report-duplicate-dirs.scm [directory-path]`

Make sure you have guile >=2.0 installed

### Note 

By default, the script ignores directories that have a cumulative size less
than 512Kb. You can change this by modifying the `*OPT-MAX-DIR-SZ*` variable
defined near the top of the script.

This script tends to use a lot of RAM, depending on how many files you have. On
my machine with ~0.5 million files, it used ~400MB.

## TODO/NOTES

* Add a `-s` flag to modify the minimum cumulative size
* Fix high RAM issues (use a global fstree, calculate values when necessary)
