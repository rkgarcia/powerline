module main

import os

fn running_as_root() bool {
	return os.getuid() == 0
}

// display_path is the identity here: a backslash is an ordinary file name
// character, not a separator.
fn display_path(path string) string {
	return path
}
