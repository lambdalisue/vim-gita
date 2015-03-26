"******************************************************************************
" vim-gita arguments/diff
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

let s:ArgumentParser = gita#util#import('ArgumentParser')

function! s:get_parser() abort " {{{
  if !exists('s:parser')
    let s:parser = s:ArgumentParser.new({
          \   'name': 'Show changes between commits, commit and working tree, etc',
          \   'validate_unknown': 0,
          \ })
    call s:parser.add_argument(
          \ '--unified', '-U',
          \ 'Generate diffs with <n> lines of context instead of the usual three. Implies -p.', {
          \   'kind': 'value',
          \ })
    call s:parser.add_argument(
          \ '--raw',
          \ 'Generate the raw format', {
          \ })
    call s:parser.add_argument(
          \ '--minimal',
          \ 'Spend extra time to make sure the smallest possible diff is produced.', {
          \ })
    call s:parser.add_argument(
          \ '--patience',
          \ 'Generate a diff using the "patience diff" algorithm.', {
          \   'conflict_with': 'algorithm',
          \ })
    call s:parser.add_argument(
          \ '--histogram',
          \ 'Generate a diff using the "histogram diff" algorithm.', {
          \   'conflict_with': 'algorithm',
          \ })
    call s:parser.add_argument(
          \ '--numstat',
          \ 'Similar to --stat, but shows number of added and deleted lines in decimal notation and pathname without abbreviation, to make it more machine friendly.', {
          \ })
    call s:parser.add_argument(
          \ '--shortstat',
          \ 'Output only the last line of the --stat format containing total number of modified files, as well as number of added and deleted lines.', {
          \ })
    call s:parser.add_argument(
          \ '--summary',
          \ 'Output a condensed summary of extended header information such as creations, renames and mode changes.', {
          \ })
    call s:parser.add_argument(
          \ '--name-only',
          \ 'Show only names of changed files.', {
          \ })
    call s:parser.add_argument(
          \ '--name-status',
          \ 'Show only names and status of changed files.', {
          \ })
    call s:parser.add_argument(
          \ '--no-renames',
          \ 'Turn off rename detection, even when the configuration file gives the default to do so.', {
          \ })
    call s:parser.add_argument(
          \ '--R', '-R',
          \ 'Swap two inputs; that is, show differences from index or on-disk file to tree contents..', {
          \ })
    call s:parser.add_argument(
          \ '--ignore-space-at-eol',
          \ 'Ignore changes in whitespace at EOL.', {
          \ })
    call s:parser.add_argument(
          \ '--ignore-space-change', '-b',
          \ 'Ignore changes in amount of whitespace. This ignores whitespace at line end, and consider all other sequences of one or more whitespace characters to be quivalent.', {
          \ })
    call s:parser.add_argument(
          \ '--ignore-all-space', '-w',
          \ 'Ignore whitespace when comparing lines. This ignores differences even if one line has whitespace where the other line has none.', {
          \ })
    call s:parser.add_argument(
          \ '--function-context', '-W',
          \ 'Show whole surrounding functions of changes.', {
          \ })
    call s:parser.add_argument(
          \ '--ignore-submodules',
          \ 'ignore changes to submodules, optional when: all, dirty, untracked (Default: all)', {
          \   'choices': ['none', 'all', 'dirty', 'untracked'],
          \   'default': 'none',
          \ })
    function! s:parser.hooks.pre_validation(args) abort
      let args = copy(a:args)
      " Automatically specify 'histogram' if no conflicted arguments
      " are specified.
      if self.has_conflict_with('histogram', args)
        " there is no conflicted arguments, thus specify 'histogram'
        let args.histogram = self.true
      endif
      return args
    endfunction
  endif
  return s:parser
endfunction " }}}

function! gita#arguments#diff#parse(bang, range, ...) abort " {{{
  let cmdline = get(a:000, 0, '')
  let settings = get(a:000, 1, {})
  let parser = s:get_parser()
  let args = [a:bang, a:range, cmdline, settings]
  let opts = call(parser.parse, args, parser)
  return opts
endfunction " }}}
function! gita#arguments#diff#complete(arglead, cmdline, cursorpos) abort " {{{
  let parser = s:get_parser()
  let args = [a:arglead, a:cmdline, a:cursorpos]
  let complete = call(parser.complete, args, parser)
  return complete
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
