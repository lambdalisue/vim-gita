let s:save_cpoptions = &cpoptions
set cpoptions&vim


let s:L = gita#import('Data.List')
let s:D = gita#import('Data.Dict')
let s:P = gita#import('System.Filepath')
let s:A = gita#import('ArgumentParser')

let s:const = {}
let s:const.bufname = 'gita%sstatus'
let s:const.filetype = 'gita-status'

let s:parser = s:A.new({
      \ 'name': 'Gita[!] status',
      \ 'description': 'Show the working tree status',
      \})
call s:parser.add_argument(
      \ '--window', '-w',
      \ 'Open a gita:status window to manipulate the working tree status (Default behavior)', {
      \   'deniable': 1,
      \   'default': 1,
      \ })
call s:parser.add_argument(
      \ '--untracked-files', '-u',
      \ 'show untracked files, optional modes: all, normal, no. (Default: all)', {
      \   'choices': ['all', 'normal', 'no'],
      \   'on_default': 'all',
      \ })
call s:parser.add_argument(
      \ '--ignored',
      \ 'show ignored files', {
      \ })
call s:parser.add_argument(
      \ '--ignore-submodules',
      \ 'ignore changes to submodules, optional when: all, dirty, untracked (Default: all)', {
      \   'choices': ['all', 'dirty', 'untracked'],
      \   'on_default': 'all',
      \ })
" TODO: Add more arguments

function! s:get_status_header(gita) abort " {{{
  let meta = a:gita.git.get_meta()
  let name = meta.local.name
  let branch = meta.local.branch_name
  let remote_name = meta.remote.name
  let remote_branch = meta.remote.branch_name
  let outgoing = a:gita.git.count_commits_ahead_of_remote()
  let incoming = a:gita.git.count_commits_behind_remote()
  let mode = a:gita.git.get_mode()
  let is_connected = !(empty(remote_name) || empty(remote_branch))

  let lines = []
  if is_connected
    call add(lines,
          \ printf('# Index and working tree status on a branch `%s/%s` <> `%s/%s`',
          \   name, branch, remote_name, remote_branch
          \))
    if outgoing > 0 && incoming > 0
      call add(lines,
            \ printf('# The branch is %d commit(s) ahead and %d commit(s) behind of `%s/%s`',
            \   outgoing, incoming, remote_name, remote_branch,
            \))     
    elseif outgoing > 0
      call add(lines,
            \ printf('# The branch is %d commit(s) ahead of `%s/%s`',
            \   outgoing, remote_name, remote_branch,
            \))
    elseif incoming > 0
      call add(lines,
            \ printf('# The branch is %d commit(s) behind `%s/%s`',
            \   incoming, remote_name, remote_branch,
            \))
    endif
  else
    call add(lines,
          \ printf('# Index and working tree status on a branch `%s/%s`',
          \   name, branch
          \))
  endif
  if !empty(mode)
    call add(lines,
          \ printf('# The branch is currently in %s', mode),
          \)
  endif
  return lines
endfunction " }}}
function! s:smart_map(...) abort " {{{
  return call('gita#action#smart_map', a:000)
endfunction " }}}

let s:actions = {}
function! s:actions.update(candidates, options, config) abort " {{{
  if !get(a:options, 'no_update')
    call gita#features#status#update(a:options, { 'force_update': 1 })
  endif
endfunction " }}}
function! s:actions.open_commit(candidates, options, config) abort " {{{
  call gita#features#commit#open(a:options)
endfunction " }}}

function! gita#features#status#exec(...) abort " {{{
  let gita = gita#get()
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  if !empty(get(options, '--', []))
    " git store files with UNIX type path separation (/)
    let options['--'] = gita#utils#path#unix_abspath(options['--'])
  endif
  let options = s:D.pick(options, [
        \ '--',
        \ 'porcelain',
        \ 'u', 'untracked-files',
        \ 'ignored',
        \ 'ignore-submodules',
        \])
  " remove -u/--untracked_files which require Git >= 1.4
  if gita.git.get_version() =~# '^-\|^1\.[1-3]\.'
    let options = s:D.omit(options, ['u', 'untracked-files'])
  endif
  return gita.operations.status(options, config)
endfunction " }}}
function! gita#features#status#exec_cached(...) abort " {{{
  let gita = gita#get()
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  let cache_name = s:P.join('status', string(s:D.pick(options, [
        \ '--',
        \ 'porcelain',
        \ 'u', 'untracked-files',
        \ 'ignored',
        \ 'ignore-submodules',
        \])))
  let cached_status = gita.git.is_updated('index', 'status') || get(config, 'force_update')
        \ ? {}
        \ : gita.git.cache.repository.get(cache_name, {})
  if !empty(cached_status)
    return cached_status
  endif
  let result = gita#features#status#exec(options, config)
  if result.status != get(config, 'success_status', 0)
    return result
  endif
  call gita.git.cache.repository.set(cache_name, result)
  return result
endfunction " }}}
function! gita#features#status#open(...) abort " {{{
  let bufname = gita#utils#buffer#bufname(
        \ substitute(s:const.bufname, '%s', g:gita#utils#buffer#separator, 'g'),
        \)
  let result = gita#monitor#open(
        \ bufname, get(a:000, 0, {}), {
        \ 'opener': g:gita#features#status#monitor_opener,
        \ 'range': g:gita#features#status#monitor_range,
        \})
  if result.status
    " gita is not available
    return
  elseif result.constructed
    " the buffer has been constructed, mean that the further construction
    " is not required.
    call gita#features#status#update({}, { 'force_update': result.loaded })
    silent execute printf("setlocal filetype=%s", s:const.filetype)
    return
  endif

  setlocal nomodifiable readonly
  call gita#action#extend_actions(s:actions)
  call gita#features#status#define_mappings()
  if g:gita#features#status#enable_default_mappings
    call gita#features#status#define_default_mappings()
  endif

  call gita#features#status#update({}, { 'force_update': 1 })
  silent execute printf("setlocal filetype=%s", s:const.filetype)
endfunction " }}}
function! gita#features#status#update(...) abort " {{{
  let gita = gita#get()
  let options = extend(
        \ deepcopy(w:_gita_options),
        \ get(a:000, 0, {}),
        \)
  let options.porcelain = 1
  let config = get(a:000, 1, {})
  let result = gita#features#status#exec_cached(options, extend({
        \ 'echo': 'fail',
        \}, config))
  if result.status != 0
    bwipe
    return
  endif
  let statuses = gita#utils#status#parse(result.stdout)

  " create statuses lines & map
  let statuses_map = {}
  let statuses_lines = []
  for status in sort(statuses.all, function('gita#utils#status#sortfn'))
    let status_record = status.record
    let statuses_map[status_record] = status
    call add(statuses_lines, status_record)
  endfor
  let w:_gita_statuses_map = statuses_map

  " update content
  let buflines = s:L.flatten([
        \ '# Press ?m and/or ?s to toggle a help of mapping and/or short format.',
        \ gita#utils#help#get('status_mapping'),
        \ gita#utils#help#get('short_format'),
        \ s:get_status_header(gita),
        \ statuses_lines,
        \ empty(statuses_map) ? ['Nothing to commit (Working tree is clean).'] : [],
        \])
  call gita#utils#buffer#update(buflines)
endfunction " }}}
function! gita#features#status#define_mappings() abort " {{{
  call gita#monitor#define_mappings()

  noremap <silent><buffer> <Plug>(gita-action-help-m)
        \ :<C-u>call gita#action#call('help', { 'name': 'status_mapping' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-update)
        \ :<C-u>call gita#action#call('update')<CR>

  noremap <silent><buffer> <Plug>(gita-action-switch)
        \ :<C-u>call gita#action#call('open_commit')<CR>
  noremap <silent><buffer> <Plug>(gita-action-switch-new)
        \ :<C-u>call gita#action#call('open_commit', { 'amend': 0, 'new_commitmsg': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-switch-amend)
        \ :<C-u>call gita#action#call('open_commit', { 'amend': 1, 'new_commitmsg': 1 })<CR>
endfunction " }}}
function! gita#features#status#define_default_mappings() abort " {{{
  call gita#monitor#define_default_mappings()

  nmap <buffer> <C-l> <Plug>(gita-action-update)
  nmap <buffer> ?m    <Plug>(gita-action-help-m)
  nmap <buffer> cc    <Plug>(gita-action-switch)
  nmap <buffer> cC    <Plug>(gita-action-switch-new)
  nmap <buffer> cA    <Plug>(gita-action-switch-amend)

  " conflict solve
  nmap <buffer><expr> ss <SID>smart_map('ss', '<Plug>(gita-action-conflict2-v)')
  nmap <buffer><expr> sh <SID>smart_map('sh', '<Plug>(gita-action-conflict2-h)')
  nmap <buffer><expr> sv <SID>smart_map('sv', '<Plug>(gita-action-conflict2-v)')

  nmap <buffer><expr> sS <SID>smart_map('sS', '<Plug>(gita-action-conflict3-v)')
  nmap <buffer><expr> sH <SID>smart_map('sH', '<Plug>(gita-action-conflict3-h)')
  nmap <buffer><expr> sV <SID>smart_map('sV', '<Plug>(gita-action-conflict3-v)')
  nmap <buffer><expr> SS <SID>smart_map('SS', '<Plug>(gita-action-conflict3-v)')
  nmap <buffer><expr> SH <SID>smart_map('SH', '<Plug>(gita-action-conflict3-h)')
  nmap <buffer><expr> SV <SID>smart_map('SV', '<Plug>(gita-action-conflict3-v)')

  " operations
  nmap <buffer><expr> << <SID>smart_map('<<', '<Plug>(gita-action-stage)')
  nmap <buffer><expr> >> <SID>smart_map('>>', '<Plug>(gita-action-unstage)')
  nmap <buffer><expr> -- <SID>smart_map('--', '<Plug>(gita-action-toggle)')
  nmap <buffer><expr> == <SID>smart_map('==', '<Plug>(gita-action-discard)')

  " raw operations
  nmap <buffer><expr> -a <SID>smart_map('-a', '<Plug>(gita-action-add)')
  nmap <buffer><expr> -A <SID>smart_map('-A', '<Plug>(gita-action-ADD)')
  nmap <buffer><expr> -r <SID>smart_map('-r', '<Plug>(gita-action-reset)')
  nmap <buffer><expr> -d <SID>smart_map('-d', '<Plug>(gita-action-rm)')
  nmap <buffer><expr> -D <SID>smart_map('-D', '<Plug>(gita-action-RM)')
  nmap <buffer><expr> -c <SID>smart_map('-c', '<Plug>(gita-action-checkout)')
  nmap <buffer><expr> -C <SID>smart_map('-C', '<Plug>(gita-action-CHECKOUT)')
  nmap <buffer><expr> -o <SID>smart_map('-o', '<Plug>(gita-action-checkout-ours)')
  nmap <buffer><expr> -t <SID>smart_map('-t', '<Plug>(gita-action-checkout-theirs)')

  " operations (range)
  vmap <buffer> << <Plug>(gita-action-stage)
  vmap <buffer> >> <Plug>(gita-action-unstage)
  vmap <buffer> -- <Plug>(gita-action-toggle)
  vmap <buffer> == <Plug>(gita-action-discard)

  " raw operations (range)
  vmap <buffer> -a <Plug>(gita-action-add)
  vmap <buffer> -A <Plug>(gita-action-ADD)
  vmap <buffer> -r <Plug>(gita-action-reset)
  vmap <buffer> -d <Plug>(gita-action-rm)
  vmap <buffer> -D <Plug>(gita-action-RM)
  vmap <buffer> -c <Plug>(gita-action-checkout)
  vmap <buffer> -C <Plug>(gita-action-CHECKOUT)
  vmap <buffer> -o <Plug>(gita-action-checkout-ours)
  vmap <buffer> -t <Plug>(gita-action-checkout-theirs)
endfunction " }}}
function! gita#features#status#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let options = extend(
          \ deepcopy(g:gita#features#status#default_options),
          \ options)
    if get(options, 'window')
      call gita#features#status#open(options)
    else
      call gita#features#status#exec(options)
    endif
  endif
endfunction " }}}
function! gita#features#status#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}
function! gita#features#status#define_highlights() abort " {{{
  highlight link GitaComment    Comment
  highlight link GitaConflicted Error
  highlight link GitaUnstaged   Constant
  highlight link GitaStaged     Special
  highlight link GitaUntracked  GitaUnstaged
  highlight link GitaIgnored    Identifier
  highlight link GitaBranch     Title
  highlight link GitaImportant  Keyword
endfunction " }}}
function! gita#features#status#define_syntax() abort " {{{
  syntax match GitaStaged     /\v^[ MADRC][ MD]/he=e-1 contains=ALL
  syntax match GitaUnstaged   /\v^[ MADRC][ MD]/hs=s+1 contains=ALL
  syntax match GitaStaged     /\v^[ MADRC]\s.*$/hs=s+3 contains=ALL
  syntax match GitaUnstaged   /\v^.[MDAU?].*$/hs=s+3 contains=ALL
  syntax match GitaIgnored    /\v^\!\!\s.*$/
  syntax match GitaUntracked  /\v^\?\?\s.*$/
  syntax match GitaConflicted /\v^%(DD|AU|UD|UA|DU|AA|UU)\s.*$/
  syntax match GitaComment    /\v^.*$/ contains=ALL
  syntax match GitaBranch     /\v`[^`]{-}`/hs=s+1,he=e-1
  syntax match GitaImportant  /\vREBASE-[mi] \d\/\d/
  syntax match GitaImportant  /\vREBASE \d\/\d/
  syntax match GitaImportant  /\vAM \d\/\d/
  syntax match GitaImportant  /\vAM\/REBASE \d\/\d/
  syntax match GitaImportant  /\v(MERGING|CHERRY-PICKING|REVERTING|BISECTING)/
endfunction " }}}


let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
