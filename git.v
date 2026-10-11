module main

import os

// git_branch returns the current branch for the repository containing `start`,
// a short commit hash when HEAD is detached, or '' outside a repository.
// It reads .git directly instead of spawning git, to keep the prompt fast.
fn git_branch(start string) string {
	mut dir := start
	for {
		dotgit := os.join_path(dir, '.git')
		if os.exists(dotgit) {
			return read_head(dotgit)
		}
		parent := os.dir(dir)
		// os.dir gives "." for a path without a separator, such as "C:".
		if parent == dir || parent == '.' {
			return ''
		}
		dir = parent
	}
	return ''
}

fn read_head(dotgit string) string {
	mut gitdir := dotgit
	// Worktrees and submodules have a .git file pointing at the real git dir.
	if os.is_file(dotgit) {
		pointer := (os.read_file(dotgit) or { return '' }).trim_space()
		if !pointer.starts_with('gitdir: ') {
			return ''
		}
		target := pointer.all_after('gitdir: ')
		gitdir = if os.is_abs_path(target) { target } else { os.join_path(os.dir(dotgit), target) }
	}
	head := (os.read_file(os.join_path(gitdir, 'HEAD')) or { return '' }).trim_space()
	if head.starts_with('ref: ') {
		return head.all_after('ref: ').trim_string_left('refs/heads/')
	}
	return head.limit(7)
}
