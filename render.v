module main

import strings

struct Segment {
	text string
	fg   int
	bg   int
	// spans, when set, replace text with pieces that each have their own color.
	spans []Span
}

struct Span {
	text string
	fg   int
}

// Shell describes how a shell wants zero-width sequences marked in its prompt,
// so that it can compute the visible prompt width correctly.
struct Shell {
	open           string
	close          string
	escape_percent bool
}

const shells = {
	'bash':       Shell{
		open:  '\x01'
		close: '\x02'
	}
	'zsh':        Shell{
		open:           '%{'
		close:          '%}'
		escape_percent: true
	}
	'fish':       Shell{}
	'powershell': Shell{}
	'plain':      Shell{}
}

fn (sh Shell) color(code string) string {
	return '${sh.open}\x1b[${code}m${sh.close}'
}

// text makes arbitrary strings (directory and branch names) safe to print:
// control characters could otherwise inject terminal escape sequences.
fn (sh Shell) text(s string) string {
	mut out := []rune{cap: s.len}
	for r in s.runes() {
		if r < 0x20 || r == 0x7f {
			out << `?`
		} else if r == `%` && sh.escape_percent {
			out << [`%`, `%`]
		} else {
			out << r
		}
	}
	return out.string()
}

fn render(segments []Segment, separator string, sh Shell) string {
	mut sb := strings.new_builder(256)
	for i, seg in segments {
		sb.write_string(sh.color('38;5;${seg.fg};48;5;${seg.bg}'))
		if seg.spans.len == 0 {
			sb.write_string(' ${sh.text(seg.text)} ')
		} else {
			sb.write_string(' ')
			for span in seg.spans {
				sb.write_string(sh.color('38;5;${span.fg}'))
				sb.write_string(sh.text(span.text))
			}
			sb.write_string(' ')
		}
		if i + 1 < segments.len {
			sb.write_string(sh.color('38;5;${seg.bg};48;5;${segments[i + 1].bg}'))
		} else {
			sb.write_string(sh.color('0;38;5;${seg.bg}'))
		}
		sb.write_string(sh.text(separator))
	}
	sb.write_string(sh.color('0'))
	sb.write_string(' ')
	return sb.str()
}
