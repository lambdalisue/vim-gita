let s:save_cpoptions = &cpoptions
set cpoptions&vim


let s:L = gita#import('Data.List')
let s:D = gita#import('Data.Dict')
let s:A = gita#import('ArgumentParser')

let s:const = {}
let s:const.bufname = 'gita%sdiff-ls'
let s:const.filetype = 'gita-diff-ls'

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
      \   'complete': function('gita#features#diff#_complete_commit'),
      \ })
call s:parser.add_argument(
      \ '--ignore-submodules',
      \ 'ignore changes to submodules, optional when: all, dirty, untracked (Default: all)', {
      \   'choices': ['all', 'dirty', 'untracked'],
      \   'on_default': 'all',
      \ })

let s:actions = {}
function! s:actions.update(candidates, options, config) abort " {{{
  if !get(a:options, 'no_update')
    call gita#features#diff_ls#update(a:options, { 'force_update': 1 })
  endif
endfunction " }}}

function! s:ensure_commit_option(options) abort " {{{
  " Ask which commit the user want to compare if no 'commit' is specified
  if empty(get(a:options, 'commit'))
    call histadd('input', 'HEAD')
    call histadd('input', 'origin/HEAD')
    call histadd('input', 'origin/HEAD...')
    call histadd('input', gita#meta#get('commit', 'origin/HEAD...'))
    let commit = gita#utils#prompt#ask(
          \ 'Which commit do you want to compare with? ',
          \ substitute(gita#meta#get('commit'), '^WORKTREE$', '', ''),
          \ 'customlist,gita#features#diff#_complete_commit',
          \)
    if empty(commit)
      call gita#utils#prompt#echo('Operation has canceled by user')
      return -1
    endif
    let a:options.commit = commit
  endif
  return 0
endfunction " }}}
function! s:parse_numstat(stdout, ...) abort " {{{
  let width = get(a:000, 0, 50)
  let stats = []
  let max_nchanged = 0
  let max_path_length = 0
  " Parse --numstat output
  for line in split(a:stdout, '\v\r?\n')
    let m = matchlist(
          \ line,
          \ '\v^(\d+)\s+(\d+)\s+(.+)$',
          \)
    let [added, deleted, relpath] = m[1 : 3]
    call add(stats, {
          \ 'added': added,
          \ 'deleted': deleted,
          \ 'path': relpath,
          \})
    if max_nchanged < (added + deleted)
      let max_nchanged = added + deleted
    endif
    if max_path_length < len(relpath)
      let max_path_length = len(relpath)
    endif
  endfor
  " Construct '--stat' like records
  let gita = gita#get()
  let nchanged_width  = len(max_nchanged . '')
  let indicator_width = width - nchanged_width - len('|  ')
  let statuses = []
  for stat in stats
    let prefix = printf(
          \ printf('| %%%dd', nchanged_width),
          \ stat.added + stat.deleted
          \)
    let indicator = printf('%s%s',
          \ repeat('+', float2nr(ceil(indicator_width * stat.added   / max_nchanged)) + (stat.added > 0 ? 1 : 0)),
          \ repeat('-', float2nr(ceil(indicator_width * stat.deleted / max_nchanged)) + (stat.deleted > 0 ? 1 : 0)),
          \)
    " Note:
    "   stat.path is relative path from git root repository
    call add(statuses, {
          \ 'path': gita#utils#path#real_abspath(
          \   gita.git.get_absolute_path(stat.path),
          \ ),
          \ 'record': printf('%s%s %s %s',
          \   stat.path,
          \   repeat(' ', max_path_length - len(stat.path)),
          \   prefix, indicator,
          \ ),
          \})
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
        \ substitute(s:const.bufname, '%s', g:gita#utils#buffer#separator, 'g'),
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
  let options['no-prefix'] = 1
  let options['no-color'] = 1
  let options.numstat = 1
  let config = get(a:000, 1, {})
  let result = gita#features#diff#exec_cached(options, extend({
        \ 'echo': 'fail',
        \}, config))
  if result.status != 0
    bwipe
    return
  endif

  let statuses = s:parse_numstat(
        \ substitute(result.stdout, '\t', '  ', 'g')
        \)

  " create statuses lines & map
  let statuses_map = {}
  let statuses_lines = []
  for status in sort(statuses)
    let status_record = status.record
    if has_key(status, 'path')
      let statuses_map[status_record] = status
    endif
    call add(statuses_lines, status_record)
  endfor
  let w:_gita_statuses_map = statuses_map

  " update content
  let [lhs, rhs] = gita#features#diff#split_commit(options.commit, options)
  let buflines = s:L.flatten([
        \ printf('# Files difference between `%s` and `%s`.', lhs, rhs),
        \ '# Press ?m to toggle a help of mapping.',
        \ gita#utils#help#get('diff_ls_mapping'),
        \ statuses_lines,
        \])
  call gita#utils#buffer#update(buflines)

  " update meta
  call gita#meta#set('commit', options.commit)
endfunction " }}}
function! gita#features#diff_ls#define_mappings() abort " {{{
  call gita#monitor#define_mappings()

  noremap <silent><buffer> <Plug>(gita-action-help-m)
        \ :<C-u>call gita#action#call('help', { 'name': 'diff_ls_mapping' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-update)
        \ :<C-u>call gita#action#call('update')<CR>
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


let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
