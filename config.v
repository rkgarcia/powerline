module main

import os
import toml

const default_toml = $embed_file('default.toml').to_string()

struct Config {
	segments  []string
	separator string

	show_user    bool
	show_host    bool
	user_fg      int
	user_bg      int
	user_root_fg int
	user_root_bg int

	dir_fg           int
	dir_bg           int
	dir_separator    string
	dir_separator_fg int
	dir_home_symbol  string
	dir_max_depth    int
	dir_keep_first   int
	dir_truncation   string

	git_fg   int
	git_bg   int
	git_icon string

	user_symbol    string
	root_symbol    string
	prompt_fg      int
	prompt_bg      int
	prompt_root_fg int
	prompt_root_bg int

	time_format string
	time_icon   string
	time_fg     int
	time_bg     int
}

// Lookup resolves keys in the user's config, falling back to default.toml.
struct Lookup {
	user     toml.Doc
	defaults toml.Doc
}

fn (l Lookup) get(key string) toml.Any {
	return l.user.value(key).default_to(l.defaults.value(key))
}

fn config_path() string {
	if path := os.getenv_opt('POWERLINE_CONFIG') {
		return path
	}
	base := os.getenv_opt('XDG_CONFIG_HOME') or { os.join_path(os.home_dir(), '.config') }
	return os.join_path(base, 'powerline', 'config.toml')
}

// load_config never fails: a broken config file must not cost you your prompt.
fn load_config() Config {
	path := config_path()
	if !os.exists(path) {
		return parse_config('')
	}
	text := os.read_file(path) or {
		eprintln('powerline: cannot read ${path}: ${err}')
		return parse_config('')
	}
	toml.parse_text(text) or {
		eprintln('powerline: ignoring ${path}: ${err}')
		return parse_config('')
	}
	return parse_config(text)
}

fn parse_config(user_text string) Config {
	defaults := toml.parse_text(default_toml) or { panic('default.toml is invalid: ${err}') }
	user := toml.parse_text(user_text) or { defaults }
	l := Lookup{user, defaults}
	return Config{
		segments:         l.get('segments').array().map(it.string())
		separator:        l.get('separator').string()
		show_user:        l.get('user.show_user').bool()
		show_host:        l.get('user.show_host').bool()
		user_fg:          l.get('user.fg').int()
		user_bg:          l.get('user.bg').int()
		user_root_fg:     l.get('user.root_fg').int()
		user_root_bg:     l.get('user.root_bg').int()
		dir_fg:           l.get('dir.fg').int()
		dir_bg:           l.get('dir.bg').int()
		dir_separator:    l.get('dir.separator').string()
		dir_separator_fg: l.get('dir.separator_fg').int()
		dir_home_symbol:  l.get('dir.home_symbol').string()
		dir_max_depth:    l.get('dir.max_depth').int()
		dir_keep_first:   l.get('dir.keep_first').int()
		dir_truncation:   l.get('dir.truncation').string()
		git_fg:           l.get('git.fg').int()
		git_bg:           l.get('git.bg').int()
		git_icon:         l.get('git.icon').string()
		user_symbol:      l.get('prompt.user_symbol').string()
		root_symbol:      l.get('prompt.root_symbol').string()
		prompt_fg:        l.get('prompt.fg').int()
		prompt_bg:        l.get('prompt.bg').int()
		prompt_root_fg:   l.get('prompt.root_fg').int()
		prompt_root_bg:   l.get('prompt.root_bg').int()
		time_format:      l.get('time.format').string()
		time_icon:        l.get('time.icon').string()
		time_fg:          l.get('time.fg').int()
		time_bg:          l.get('time.bg').int()
	}
}
