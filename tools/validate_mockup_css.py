"""Validate the mockup's <style> block by checking SELECTORS, not braces.
Brace/comment counting passed while an unopened comment silently ate a rule."""
import re, sys
src = open(sys.argv[1]).read()
css = src[src.index('<style>')+7 : src.index('</style>')]

# strip comments, preserving newlines for line numbers
stripped = re.sub(r'/\*.*?\*/', lambda m: re.sub(r'[^\n]', ' ', m.group()), css, flags=re.S)
if '*/' in stripped:
    n = css[:stripped.index('*/')].count('\n') + 1
    print(f'FAIL: stray */ outside a comment near line {n} (unopened comment)'); sys.exit(1)
if '/*' in stripped:
    print('FAIL: unterminated comment'); sys.exit(1)

# a selector is whatever precedes a top-level {
SEL_OK = re.compile(r'^[\w\s.#:,\->+*\[\]="\'()%@&~^|$]+$')
bad, depth, buf, line = [], 0, '', 1
for ch in stripped:
    if ch == '\n': line += 1
    if ch == '{':
        depth += 1
        if depth == 1:
            sel = ' '.join(buf.split())
            if sel and not SEL_OK.match(sel):
                bad.append((line, sel[:90]))
            # prose smell: a selector with many words and no . # : is suspicious
            elif sel and not sel.startswith('@') and len(sel.split()) > 6 \
                 and not any(c in sel for c in '.#:['):
                bad.append((line, 'prose-like selector: ' + sel[:90]))
            buf = ''
    elif ch == '}':
        depth -= 1
        buf = ''
        if depth < 0:
            bad.append((line, 'stray }')); depth = 0
    elif depth == 0:
        buf += ch

if depth: bad.append((line, f'{depth} unclosed block(s)'))
# leftover text after the last } that isn't whitespace
if buf.strip(): bad.append((line, 'trailing text outside any rule: ' + ' '.join(buf.split())[:80]))

# every var() must resolve
defined = set(re.findall(r'(--[\w-]+)\s*:', stripped))
for v in sorted(set(re.findall(r'var\((--[\w-]+)\s*\)', stripped)) - defined):
    bad.append((0, f'undefined custom property {v}'))

if bad:
    for ln, msg in bad: print(f'FAIL line {ln}: {msg}')
    sys.exit(1)
print('CSS OK — selectors, blocks and custom properties all resolve')
