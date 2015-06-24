let s:save_cpo = &cpo
set cpo&vim


let s:L = gita#utils#import('Data.List')
let s:D = gita#utils#import('Data.Dict')
let s:S = gita#utils#import('VCS.Git.StatusParser')
let s:A = gita#utils#import('ArgumentParser')


let s:parser = s:A.new({
      \ 'name': 'Gita diff-ls',
      \ 'description': 'List filenames and statuses different between two commit',
      \})
call s:parser.add_argument(
      \ 'commit', [
      \   'A commit string to specify how to compare commits.',
      \   'If it is omitted, it would be interactively requested.',
      \ ], {
      \   'complete': function('gita#completes#complete_local_branch'),
      \ })

let s:actions = {}
function! s:actions.update(statuses, options) abort " {{{
  call gita#features#diff_ls#update(a:options)
endfunction " }}}

function! gita#features#diff_ls#open(...) abort " {{{
  let options = gita#window#extend_options(get(a:000, 0, {}))
  " Ask which commit the user want to compare if no 'commit' is specified
  if empty(get(options, 'commit')) || get(options, 'new')
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
  " Open the window
  let bufname_sep = has('unix') ? ':' : '_'
  call gita#window#open('diff_ls', options, {
        \ 'bufname': join(['gita', 'diff-ls', options.commit], bufname_sep),
        \ 'filetype': 'gita-diff-ls',
        \})
  call gita#features#diff_ls#update(options)
endfunction " }}}
function! gita#features#diff_ls#update(...) abort " {{{
  let options = gita#window#extend_options(get(a:000, 0, {}))
  let gita = gita#core#get()
  let result = gita.operations.diff({
        \ 'no_prefix': 1,
        \ 'no_color': 1,
        \ 'name_status': 1,
        \ 'commit': substitute(options.commit, '^INDEX$', '', ''),
        \}, {
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
        \ ['# Files changed from "' . options.commit . '".',
        \  '# Press ?m and/or ?s to toggle a help of mapping and/or short format.'],
        \ gita#utils#help#get('changes_mapping'),
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
