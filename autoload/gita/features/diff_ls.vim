let s:save_cpo = &cpo
set cpo&vim


let s:L = gita#utils#import('Data.List')
let s:D = gita#utils#import('Data.Dict')
let s:S = gita#utils#import('VCS.Git.StatusParser')
let s:A = gita#utils#import('ArgumentParser')

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

function! gita#features#diff_ls#open(...) abort " {{{
  let options = extend(
        \ deepcopy(get(w:, '_gita_options', {})),
        \ get(a:000, 0, {}),
        \)
  " Ask which commit the user want to compare if no 'commit' is specified
  if empty(get(options, 'commit')) || get(options, 'diff_ls_new')
    let commit = gita#utils#ask(
          \ 'Which commit do you want to compare with? ',
          \ get(options, 'commit', 'master'),
          \)
    if empty(commit)
      call gita#utils#info('Operation has canceled by user')
      return
    endif
    let options.commit = commit
  endif

  let bufname = join([s:const.bufname, options.commit], s:const.bufname_sep)
  let enable_default_mappings = g:gita#features#diff_ls#enable_default_mappings
  let result = gita#monitor#open(bufname, options, {
        \ 'enable_default_mappings': enable_default_mappings,
        \ 'opener': g:gita#features#diff_ls#monitor_opener,
        \ 'range': g:gita#features#diff_ls#monitor_range,
        \})
  if result.status == -1
    " gita is not available
    return
  elseif result.status == 1
    " the buffer is already constructed
    call gita#features#diff_ls#update({}, { 'force_update': 1 })
    silent execute printf("setlocal filetype=%s", s:const.filetype)
    return
  endif
  call gita#action#extend_actions(s:actions)

  " Define loccal options
  setlocal nomodifiable readonly

  noremap <silent><buffer> <Plug>(gita-action-help-m)
        \ :<C-u>call gita#action#exec('help', { 'name': 'diff_ls_mapping' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-update)
        \ :<C-u>call gita#action#exec('update')<CR>

  " Define extra actual key mappings
  if enable_default_mappings
    nmap <buffer> <C-l> <Plug>(gita-action-update)
    nmap <buffer> ?m    <Plug>(gita-action-help-m)
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
  let options.name_status = 1
  let config = get(a:000, 1, {})
  let result = gita#features#diff#exec_cached(options, extend({
        \ 'echo': 'fail',
        \}, config))
  if result.status != 0
    bwipe
    return
  endif
  let statuses = s:S.parse(substitute(result.stdout, '\t', '  ', 'g'))

  " create statuses lines & map
  let statuses_map = {}
  let statuses_lines = []
  for status in statuses.all
    let line = printf('%s', status.record)
    call add(statuses_lines, line)
    let statuses_map[line] = status
  endfor
  let w:_gita_statuses_map = statuses_map

  " update content
  let buflines = s:L.flatten([
        \ ['# Files difference between "' . options.commit . '".',
        \  '# Press ?m and/or ?s to toggle a help of mapping and/or short format.'],
        \ gita#utils#help#get('diff_ls_mapping'),
        \ gita#utils#help#get('short_format'),
        \ statuses_lines,
        \])
  call gita#utils#buffer#update(buflines)
endfunction " }}}
function! gita#features#diff_ls#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    call gita#features#diff_ls#open(options)
  endif
endfunction " }}}
function! gita#features#diff_ls#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}
function! gita#features#diff_ls#define_highlights() abort " {{{
  highlight link GitaComment    Comment
  highlight link GitaConflicted Error
  highlight link GitaUnstaged   Constant
  highlight link GitaStaged     Special
  highlight link GitaUntracked  GitaUnstaged
  highlight link GitaIgnored    Identifier
  highlight link GitaBranch     Title
endfunction " }}}
function! gita#features#diff_ls#define_syntax() abort " {{{
  syntax match GitaStaged     /\v^[ MADRC][ MD]/he=e-1 contains=ALL
  syntax match GitaUnstaged   /\v^[ MADRC][ MD]/hs=s+1 contains=ALL
  syntax match GitaStaged     /\v^[ MADRC]\s.*$/hs=s+3 contains=ALL
  syntax match GitaUnstaged   /\v^.[MDAU?].*$/hs=s+3 contains=ALL
  syntax match GitaIgnored    /\v^\!\!\s.*$/
  syntax match GitaUntracked  /\v^\?\?\s.*$/
  syntax match GitaConflicted /\v^%(DD|AU|UD|UA|DU|AA|UU)\s.*$/
  syntax match GitaComment    /\v^.*$/ contains=ALL
  syntax match GitaBranch     /\v`[^`]{-}`/hs=s+1,he=e-1
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
