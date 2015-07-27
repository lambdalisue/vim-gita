let s:save_cpo = &cpo
set cpo&vim


let s:L = gita#import('Data.List')
let s:D = gita#import('Data.Dict')
let s:A = gita#import('ArgumentParser')

let s:const = {}
let s:const.bufname_sep = has('unix') ? ':' : '-'
let s:const.bufname = join(['gita', 'diff-ls'], s:const.bufname_sep)
let s:const.filetype = 'gita-diff-ls'

function! s:complete_commit(arglead, cmdline, cursorpos, ...) abort " {{{
  let leading = matchstr(a:arglead, '^.*\.\.\.\?')
  let arglead = substitute(a:arglead, '^.*\.\.\.\?', '', '')
  let candidates = call('gita#utils#completes#complete_local_branch', extend(
        \ [arglead, a:cmdline, a:cursorpos],
        \ a:000,
        \))
  let candidates = map(candidates, 'leading . v:val')
  return candidates
endfunction " }}}
let s:parser = s:A.new({
      \ 'name': 'Gita[!] diff-ls',
      \ 'description': 'Show filename and status difference',
      \})
call s:parser.add_argument(
      \ 'commit', [
      \   'A commit which you want to compare with.',
      \   'If nothing is specified, it show changes in working tree relative to the index (staging area for next commit).',
      \   'If <commit> is specified, it show changes in working tree relative to the named <commit>.',
      \   'If <commit>..<commit> is specified, it show the changes between two arbitrary <commit>.',
      \   'If <commit>...<commit> is specified, it show thechanges on the branch containing and up to the second <commit>, starting at a common ancestor of both <commit>.',
      \ ], {
      \   'complete': function('s:complete_commit'),
      \ })
call s:parser.add_argument(
      \ '--ignore-submodules',
      \ 'ignore changes to submodules, optional when: all, dirty, untracked (Default: all)', {
      \   'choices': ['all', 'dirty', 'untracked'],
      \   'on_default': 'all',
      \ })
call s:parser.add_argument(
      \ '--window', '-w',
      \ 'Open a gita:diff:ls window to show changed files (Default behavior)', {
      \   'deniable': 1,
      \   'default': 1,
      \ })

let s:actions = {}
function! s:actions.update(statuses, options) abort " {{{
  call gita#features#diff_ls#update(a:options, { 'force_update': 1 })
endfunction " }}}

function! s:ensure_commit_option(options) abort " {{{
  " Ask which commit the user want to compare if no 'commit' is specified
  if empty(get(a:options, 'commit'))
    call histadd('input', 'origin/HEAD')
    call histadd('input', 'origin/HEAD...')
    call histadd('input', get(a:options, 'commit', 'origin/HEAD...'))
    let commit = gita#utils#prompt#ask(
          \ 'Which commit do you want to compare with? ',
          \)
    if empty(commit)
      call gita#utils#prompt#echo('Operation has canceled by user')
      return -1
    endif
    let a:options.commit = commit
  endif
  return 0
endfunction " }}}
function! s:split_commit(commit) abort " {{{
  if a:commit =~# '\v^[^.]*\.\.\.[^.]*$'
    let rhs = matchlist(
          \ a:commit,
          \ '\v^([^.]*)\.\.\.([^.]*)$',
          \)[2]
    return [ a:commit, empty(rhs) ? 'HEAD' : rhs ]
  elseif a:commit =~# '\v^[^.]*\.\.[^.]*$'
    let [lhs, rhs] = matchlist(
          \ a:commit,
          \ '\v^([^.]*)\.\.([^.]*)$',
          \)[ 1 : 2 ]
    return [ empty(lhs) ? 'HEAD' : lhs, empty(rhs) ? 'HEAD' : rhs ]
  else
    return [ 'HEAD', a:commit ]
  endif
endfunction " }}}
function! s:parse_stat(stdout) abort " {{{
  let statuses = []
  for line in split(a:stdout, '\v\r?\n')
    let relpath = substitute(
          \ escape(line, '\'),
          \ '\v%(^\s+|\s+\|\s+\d+\s+\+*\-*$)',
          \ '', 'g',
          \)
    let status = { 'record': line[1:] }
    if relpath !=# line
      let status.path = gita#utils#ensure_realpath(
            \ gita#utils#ensure_abspath(relpath),
            \)
    endif
    call add(statuses, status)
  endfor
  return statuses
endfunction " }}}

function! gita#features#diff_ls#open(...) abort " {{{
  let options = extend(
        \ deepcopy(get(w:, '_gita_options', {})),
        \ get(a:000, 0, {}),
        \)
  if s:ensure_commit_option(options)
    return
  endif
  let bufname = gita#utils#buffer#bufname(
        \ s:const.bufname,
        \ options.commit,
        \)
  let result = gita#monitor#open(bufname, options, {
        \ 'opener': g:gita#features#diff_ls#monitor_opener,
        \ 'range': g:gita#features#diff_ls#monitor_range,
        \})
  if result.status
    " gita is not available
    return
  elseif result.constructed
    " the buffer has been constructed, mean that the further construction
    " is not required.
    call gita#features#diff_ls#update({}, { 'force_update': result.loaded })
    silent execute printf("setlocal filetype=%s", s:const.filetype)
    return
  endif

  setlocal nomodifiable readonly
  call gita#action#extend_actions(s:actions)
  call gita#features#diff_ls#define_mappings()
  if g:gita#features#diff_ls#enable_default_mappings
    call gita#features#diff_ls#define_default_mappings()
  endif

  call gita#features#diff_ls#update({}, { 'force_update': 1 })
  silent execute printf("setlocal filetype=%s", s:const.filetype)
endfunction " }}}
function! gita#features#diff_ls#update(...) abort " {{{
  let options = extend(
        \ deepcopy(w:_gita_options),
        \ get(a:000, 0, {}),
        \)
  let options.no_prefix = 1
  let options.no_color = 1
  let options.stat = winwidth(0)
  let config = get(a:000, 1, {})
  let result = gita#features#diff#exec_cached(options, extend({
        \ 'echo': 'fail',
        \}, config))
  if result.status != 0
    bwipe
    return
  endif

  let statuses = s:parse_stat(
        \ substitute(result.stdout, '\t', '  ', 'g')
        \)

  " create statuses lines & map
  let statuses_map = {}
  let statuses_lines = []
  for status in statuses
    let status_record = status.record
    if has_key(status, 'path')
      let statuses_map[status_record] = status
    endif
    call add(statuses_lines, status_record)
  endfor
  let w:_gita_statuses_map = statuses_map

  " update content
  let [lhs, rhs] = s:split_commit(options.commit)
  let buflines = s:L.flatten([
        \ printf('# Files difference between `%s` and `%s`.', lhs, rhs),
        \ '# Press ?m to toggle a help of mapping.',
        \ gita#utils#help#get('diff_ls_mapping'),
        \ statuses_lines,
        \])
  call gita#utils#buffer#update(buflines)
endfunction " }}}
function! gita#features#diff_ls#define_mappings() abort " {{{
  call gita#monitor#define_mappings()

  noremap <silent><buffer> <Plug>(gita-action-help-m)
        \ :<C-u>call gita#action#exec('help', { 'name': 'diff_ls_mapping' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-update)
        \ :<C-u>call gita#action#exec('update')<CR>
endfunction " }}}
function! gita#features#diff_ls#define_default_mappings() abort " {{{
  call gita#monitor#define_default_mappings()
  unmap <buffer> ?s

  nmap <buffer> <C-l> <Plug>(gita-action-update)
  nmap <buffer> ?m    <Plug>(gita-action-help-m)
endfunction " }}}
function! gita#features#diff_ls#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let options = extend(
          \ deepcopy(g:gita#features#diff_ls#default_options),
          \ options)
    call gita#features#diff_ls#open(options)
  endif
endfunction " }}}
function! gita#features#diff_ls#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}
function! gita#features#diff_ls#define_highlights() abort " {{{
  highlight default link GitaCommit       Tag
  highlight default link GitaComment      Comment
  highlight default link GitaPath         Statement
  highlight default link GitaChangedCount Title
  highlight default link GitaAdded        Special
  highlight default link GitaDeleted      Constant
endfunction " }}}
function! gita#features#diff_ls#define_syntax() abort " {{{
  syntax match GitaPath       /\v^.*\ze\s+\|/
  syntax match GitaStat       /\v\|\s+\d+\s+\+*\-*$/
        \ contains=GitaChangedCount,GitaAdded,GitaDeleted
  syntax match GitaChangedCount /\v\d+/ contained display
  syntax match GitaAdded        /\v\++/ contained display
  syntax match GitaDeleted      /\v\-+/ contained display
  syntax match GitaComment      /\v^#.*$/ contains=GitaCommit
  syntax match GitaCommit       /\v\`.{-}\`/ contained display
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
