module main

// Windows has no uid 0. An elevated (Administrator) session is not detected,
// so the root colors and symbol are never used.
fn running_as_root() bool {
	return false
}

// display_path turns C:\Users\me into C:/Users/me, the form dir_spans expects.
fn display_path(path string) string {
	return path.replace('\\', '/')
}
