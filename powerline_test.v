module main

import os

fn test_defaults() {
	cfg := parse_config('')
	assert cfg.segments == ['time', 'user', 'dir', 'git', 'prompt']
	assert cfg.show_host
	assert cfg.user_symbol == '$'
	assert cfg.root_symbol == '#'
	assert cfg.separator == ''
}

fn test_user_config_overrides_only_what_it_sets() {
	cfg := parse_config('[user]\nshow_host = false\n[dir]\nmax_depth = 2\n')
	assert !cfg.show_host
	assert cfg.show_user
	assert cfg.dir_max_depth == 2
	assert cfg.user_bg == 31
}

fn dir_text(cwd string, home string, cfg Config) string {
	return dir_spans(cwd, home, cfg).map(it.text).join('')
}

fn test_dir_text() {
	cfg :=
		parse_config('[dir]\nseparator = "/"\nhome_symbol = "\uf015 "\nmax_depth = 3\nkeep_first = 0\ntruncation = "..."\n')
	assert dir_text('/home/me', '/home/me', cfg) == '\uf015'
	assert dir_text('/home/me/src/app', '/home/me', cfg) == '\uf015 /src/app'
	assert dir_text('/home/meow', '/home/me', cfg) == '/home/meow'
	assert dir_text('/', '/home/me', cfg) == '/'
	assert dir_text('/home/me/a/b/c', '/home/me', cfg) == '\uf015 /a/b/c'
	assert dir_text('/home/me/a/b/c/d', '/home/me', cfg) == '\uf015 /.../b/c/d'
	assert dir_text('/usr/share/fonts/truetype', '/home/me', cfg) == '.../share/fonts/truetype'

	custom := parse_config('[dir]\nseparator = "/"\nhome_symbol = "~"\nmax_depth = 0\n')
	assert dir_text('/home/me/a/b/c', '/home/me', custom) == '~/a/b/c'

	full := parse_config('[dir]\nseparator = "/"\nhome_symbol = ""\n')
	assert dir_text('/home/me', '/home/me', full) == '/home/me'
}

fn test_dir_separator() {
	cfg :=
		parse_config('[dir]\nseparator = " > "\nhome_symbol = "\uf015 "\nmax_depth = 3\nkeep_first = 0\ntruncation = "..."\n')
	assert dir_text('/home/me', '/home/me', cfg) == '\uf015'
	assert dir_text('/home/me/src/app', '/home/me', cfg) == '\uf015  > src > app'
	assert dir_text('/home/me/a/b/c/d', '/home/me', cfg) == '\uf015  > ... > b > c > d'
	assert dir_text('/usr/share', '/home/me', cfg) == '/ > usr > share'
	assert dir_text('/usr/share/fonts/truetype', '/home/me', cfg) == '... > share > fonts > truetype'
	assert dir_text('/', '/home/me', cfg) == '/'

	tight :=
		parse_config('[dir]\nseparator = ">"\nhome_symbol = "\uf015 "\nmax_depth = 3\nkeep_first = 0\ntruncation = "..."\n')
	assert dir_text('/home/me/src', '/home/me', tight) == '\uf015 >src'
}

fn test_dir_keep_first() {
	cfg :=
		parse_config('[dir]\nseparator = "/"\nhome_symbol = "~"\nmax_depth = 1\nkeep_first = 1\ntruncation = "..."\n')
	assert dir_text('/home/me/a/b/c/d', '/home/me', cfg) == '~/a/.../d'
	assert dir_text('/home/me/a/b', '/home/me', cfg) == '~/a/b'
	assert dir_text('/home/me/a', '/home/me', cfg) == '~/a'
	assert dir_text('/usr/share/fonts/truetype', '/home/me', cfg) == '/usr/.../truetype'
	assert dir_text('/usr/share', '/home/me', cfg) == '/usr/share'

	chevron :=
		parse_config('[dir]\nseparator = " > "\nhome_symbol = "~"\nmax_depth = 1\nkeep_first = 1\ntruncation = "..."\n')
	assert dir_text('/usr/share/fonts/truetype', '/home/me', chevron) == '/ > usr > ... > truetype'
}

fn test_dir_separator_color() {
	cfg :=
		parse_config('[dir]\nfg = 7\nseparator = "/"\nseparator_fg = 9\nhome_symbol = "\uf015 "\n')
	assert dir_spans('/usr/share', '/home/me', cfg) == [Span{'/', 9},
		Span{'usr', 7}, Span{'/', 9}, Span{'share', 7}]
	assert dir_spans('/home/me/a', '/home/me', cfg) == [Span{'\uf015 ', 7},
		Span{'/', 9}, Span{'a', 7}]
	seg := Segment{
		spans: [Span{'a', 7}, Span{'/', 9}]
		bg:    2
	}
	assert render([seg], '>', shells['plain']).contains(' \x1b[38;5;7ma\x1b[38;5;9m/ ')
}

fn test_git_branch() {
	root := os.join_path(os.vtmp_dir(), 'powerline_git_test')
	os.rmdir_all(root) or {}
	defer {
		os.rmdir_all(root) or {}
	}
	repo := os.join_path(root, 'repo')
	nested := os.join_path(repo, 'a', 'b')
	os.mkdir_all(nested)!
	os.mkdir_all(os.join_path(repo, '.git'))!
	head := os.join_path(repo, '.git', 'HEAD')

	os.write_file(head, 'ref: refs/heads/feature/x\n')!
	assert git_branch(nested) == 'feature/x'

	os.write_file(head, '0123456789abcdef0123456789abcdef01234567\n')!
	assert git_branch(repo) == '0123456'

	// Worktree: .git is a file pointing at the real git dir.
	tree := os.join_path(root, 'tree')
	os.mkdir_all(tree)!
	os.write_file(head, 'ref: refs/heads/main\n')!
	os.write_file(os.join_path(tree, '.git'), 'gitdir: ../repo/.git\n')!
	assert git_branch(tree) == 'main'

	assert git_branch(root) == ''
}

fn test_render() {
	segs := [Segment{'a', 1, 2, []}, Segment{'b', 3, 4, []}]
	assert render(segs, '>', shells['plain']) == '\x1b[38;5;1;48;5;2m a \x1b[38;5;2;48;5;4m>\x1b[38;5;3;48;5;4m b \x1b[0;38;5;4m>\x1b[0m '
	// bash needs every escape sequence wrapped in \x01 .. \x02
	assert render(segs, '>', shells['bash']).count('\x01') == 5
}

fn test_time_segment() {
	segs := build_segments(parse_config('segments = ["time"]\n[time]\nicon = "T"\n'))
	assert segs.len == 1
	assert segs[0].text.starts_with('T ')
	assert segs[0].text.len == 'T 00:00'.len
}

fn test_text_is_sanitized() {
	assert shells['plain'].text('a\x1b[31mb\n') == 'a?[31mb?'
	assert shells['zsh'].text('100%') == '100%%'
	assert shells['bash'].text('100%') == '100%'
}
