# report-duplicate-dirs

Display paths to duplicate directories in the filesystem

Directories are compared to each other based on a "checksum" defined by

* The total cumulative size of every file in a directory

If this stat is equivalent between directories, they are considered the same
directory and paths to both will be printed to stdout

## Usage

`guile ./report-duplicate-dirs.scm [directory-path]`

### Note 

By default, the script ignores directories that have a cumulative size less
than 512Kb. You can change this by modifying the `*OPT-MAX-DIR-SZ*` variable
defined near the top of the script.

## TODO/NOTES

* Add a `-s` flag to modify the minimum cumulative size
* Add another checksum condition
  * Compare between lists of files/subdirectories in every directory?
  * Use the FTW structure to sort+compare on-demand?
