module main

import os
import time

const usage = 'Usage:
  powerline prompt [bash|zsh|fish|powershell|plain]   print the prompt (default: plain)
  powerline init <bash|zsh|fish|powershell>           print shell setup code
  powerline config                                    print the default configuration'

fn main() {
	args := os.args[1..]
	cmd := args[0] or { 'prompt' }
	match cmd {
		'prompt' {
			name := args[1] or { 'plain' }
			sh := shells[name] or { fail('unknown shell "${name}"') }
			cfg := load_config()
			print(render(build_segments(cfg), cfg.separator, sh))
		}
		'init' {
			name := args[1] or { fail('init needs a shell name') }
			print(init_script(name) or { fail(err.msg()) })
		}
		'config' {
			print(default_toml)
		}
		'-h', '--help', 'help' {
			println(usage)
		}
		else {
			fail('unknown command "${cmd}"')
		}
	}
}

@[noreturn]
fn fail(msg string) {
	eprintln('powerline: ${msg}\n${usage}')
	exit(2)
}

fn build_segments(cfg Config) []Segment {
	is_root := running_as_root()
	// $PWD keeps the path the user typed (through symlinks); getwd resolves it.
	cwd := os.getenv_opt('PWD') or { os.getwd() }
	mut segments := []Segment{}
	for name in cfg.segments {
		match name {
			'time' {
				now := time.now().custom_format(cfg.time_format)
				segments << Segment{
					text: '${cfg.time_icon} ${now}'.trim_space()
					fg:   cfg.time_fg
					bg:   cfg.time_bg
				}
			}
			'user' {
				text := user_text(cfg)
				if text != '' {
					segments << Segment{
						text: text
						fg:   if is_root { cfg.user_root_fg } else { cfg.user_fg }
						bg:   if is_root { cfg.user_root_bg } else { cfg.user_bg }
					}
				}
			}
			'dir' {
				segments << Segment{
					spans: dir_spans(display_path(cwd), display_path(os.home_dir()), cfg)
					fg:    cfg.dir_fg
					bg:    cfg.dir_bg
				}
			}
			'git' {
				branch := git_branch(cwd)
				if branch != '' {
					segments << Segment{
						text: '${cfg.git_icon} ${branch}'.trim_space()
						fg:   cfg.git_fg
						bg:   cfg.git_bg
					}
				}
			}
			'prompt' {
				segments << Segment{
					text: if is_root { cfg.root_symbol } else { cfg.user_symbol }
					fg:   if is_root { cfg.prompt_root_fg } else { cfg.prompt_fg }
					bg:   if is_root { cfg.prompt_root_bg } else { cfg.prompt_bg }
				}
			}
			else {}
		}
	}
	return segments
}

fn user_text(cfg Config) string {
	mut parts := []string{}
	if cfg.show_user {
		parts << os.getenv_opt('USER') or { os.loginname() or { '?' } }
	}
	if cfg.show_host {
		parts << (os.hostname() or { '?' }).all_before('.')
	}
	return parts.join('@')
}

// dir_spans returns the folders and the separators between them as separate
// spans, so the separators can have their own color.
fn dir_spans(cwd string, home string, cfg Config) []Span {
	sep := cfg.dir_separator
	in_home := cfg.dir_home_symbol != '' && home != ''
		&& (cwd == home || cwd.starts_with(home + '/'))
	rest := if in_home { cwd[home.len..] } else { cwd }
	parts := rest.split('/').filter(it != '')
	keep_first := if cfg.dir_keep_first > 0 { cfg.dir_keep_first } else { 0 }
	truncated := cfg.dir_max_depth > 0 && parts.len > keep_first + cfg.dir_max_depth
	// The path is shown from the root unless its beginning was cut off. With
	// "/" an absolute path starts with the separator; any other separator
	// needs the root spelled out as its own item. A Windows path (C:/src) has
	// no root to show: it starts with its drive.
	at_root := !in_home && cwd.starts_with('/') && (!truncated || keep_first > 0)

	// The home symbol is its own item so that shortening never removes it.
	mut items := []string{}
	if in_home {
		items << cfg.dir_home_symbol
	} else if at_root && (sep != '/' || parts.len == 0) {
		items << '/'
	}
	if truncated {
		items << parts[..keep_first]
		items << cfg.dir_truncation
		items << parts[parts.len - cfg.dir_max_depth..]
	} else {
		items << parts
	}

	mut spans := []Span{}
	for i, item in items {
		if i > 0 || (at_root && sep == '/' && parts.len > 0) {
			spans << Span{sep, cfg.dir_separator_fg}
		}
		// The home symbol keeps its trailing space even before a padded
		// separator: a wide icon covers that cell, so the gap would vanish.
		// Only when it stands alone (at home itself) is the space dropped.
		text := if i == items.len - 1 { item.trim_right(' ') } else { item }
		spans << Span{text, cfg.dir_fg}
	}
	return spans
}

fn init_script(shell string) !string {
	// Single-quote the binary path so the generated code survives odd paths.
	exe := "'" + os.executable().replace("'", "'\\''") + "'"
	return match shell {
		'bash' {
			// PS1 only references a variable: bash does not re-expand its
			// value, so a directory named '$(cmd)' cannot run anything.
			'__powerline_prompt() { __powerline_ps1="$(${exe} prompt bash)"; }
if [[ "\${PROMPT_COMMAND-}" != *__powerline_prompt* ]]; then
  PROMPT_COMMAND="__powerline_prompt\${PROMPT_COMMAND:+;\$PROMPT_COMMAND}"
fi
PS1=\'\${__powerline_ps1}\'
'
		}
		'zsh' {
			'setopt prompt_subst
__powerline_precmd() { __powerline_ps1="$(${exe} prompt zsh)" }
autoload -Uz add-zsh-hook
add-zsh-hook precmd __powerline_precmd
PROMPT=\'\${__powerline_ps1}\'
'
		}
		'fish' {
			'function fish_prompt
    ${exe} prompt fish
end
'
		}
		'powershell' {
			ps_exe := "'" + os.executable().replace("'", "''") + "'"
			// PowerShell never updates \$env:PWD, and Windows PowerShell decodes
			// program output with the legacy code page unless told otherwise.
			'function global:prompt {
    \$code = \$global:LASTEXITCODE
    \$env:PWD = \$PWD.ProviderPath
    \$enc = [Console]::OutputEncoding
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    try { & ${ps_exe} prompt powershell } finally {
        [Console]::OutputEncoding = \$enc
        \$global:LASTEXITCODE = \$code
    }
}
'
		}
		else {
			error('unsupported shell "${shell}"')
		}
	}
}
