let s:save_cpo = &cpo
set cpo&vim


let s:L = gita#utils#import('Data.List')
let s:D = gita#utils#import('Data.Dict')
let s:S = gita#utils#import('VCS.Git.StatusParser')
let s:A = gita#utils#import('ArgumentParser')

let s:const = {}
let s:const.bufname_sep = has('unix') ? ':' : '-'
let s:const.bufname = join(['gita', 'diff', 'ls'], s:const.bufname_sep)
let s:const.filetype = 'gita-diff-ls'

let s:parser = s:A.new({
      \ 'name': 'Gita diff-ls',
      \ 'description': 'Show filenames and statuses different',
      \})
call s:parser.add_argument(
      \ '--window', '-w',
      \ 'Open a gita:diff:ls window to show changed files (Default behavior)', {
      \   'deniable': 1,
      \   'default': 1,
      \ })
call s:parser.add_argument(
      \ 'revision', [
      \   'A revision (e.g. HEAD) which you want to compare with.',
      \ ], {
      \   'complete': function('gita#completes#complete_local_branch'),
      \ })

let s:actions = {}
function! s:actions.update(statuses, options) abort " {{{
  call gita#features#diff_ls#update(a:options)
endfunction " }}}

function! gita#features#diff_ls#open(...) abort " {{{
  let options = extend(
        \ deepcopy(w:_gita_options),
        \ get(a:000, 0, {}),
        \)
  " Ask which commit the user want to compare if no 'commit' is specified
  if empty(get(options, 'revision')) || get(options, 'diff_ls_new')
    let revision = gita#utils#ask(
          \ 'Which revision do you want to compare with? ',
          \ get(options, 'revision', 'master'),
          \)
    if empty(revision)
      call gita#utils#info('Operation has canceled by user')
      return
    endif
    let options.revision = revision
  endif

  let bufname = join([s:const.bufname, options.revision], s:const.bufname_sep)
  let result = gita#display#open(bufname, options)
  if result == -1
    " gita is not available
    return
  else result == 1
    " the buffer is already constructed
    call gita#features#diff_ls#update()
    silent execute printf("setlocal filetype=%s", s:const.filetype)
    return
  endif
  call gita#display#extend_actions(s:actions)

  " Define loccal options
  setlocal nomodifiable

  noremap <silent><buffer> <Plug>(gita-action-help-m)
        \ :<C-u>call gita#display#action('help', { 'name': 'diff_ls_mapping' })<CR>

  call gita#features#diff_ls#update()
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
  let result = gita#features#diff#exec(options, {
        \ 'echo': 'fail',
        \})
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
        \ ['# Files difference between "' . options.revision . '".',
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
