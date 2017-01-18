let s:V = gita#vital()
let s:Console = s:V.import('Vim.Console')

function! s:action_checkout(candidate, options) abort
  let options = extend({
        \ 'track': 0,
        \}, a:options)
  if a:candidate.is_remote
    let name = substitute(a:candidate.name, '^origin/', '', '')
    let args = [
          \ 'checkout',
          \ '-b' . name,
          \ empty(options.track) ? '' : '--track',
          \ a:candidate.name,
          \]
  else
    let args = ['checkout', a:candidate.name]
  endif
  let git = gita#core#get_or_fail()
  call gita#process#execute(git, args, { 'quiet': 1 })
  call gita#trigger_modified()
endfunction

function! s:action_rename(candidate, options) abort
  let options = extend({
        \ 'force': 0,
        \}, a:options)
  if a:candidate.is_remote
    call gita#throw('Attention: Renaming a remote branch is not supported.')
  endif

  let newname = s:Console.ask(
        \ printf('Please input a new branch name of "%s": ', a:candidate.name),
        \ a:candidate.name,
        \)
  if empty(newname)
    call gita#throw('Cancel: Canceled by user')
  endif
  let args = [
        \ 'branch',
        \ options.force ? '-M' : '--move',
        \ a:candidate.name,
        \ newname,
        \]
  let git = gita#core#get_or_fail()
  call gita#process#execute(git, args)
  call gita#trigger_modified()
endfunction

function! s:action_delete(candidate, options) abort
  let options = extend({
        \ 'force': 0,
        \}, a:options)
  if a:candidate.is_remote
    if !options.force
      if !s:Console.confirm(printf(
            \ 'Are you sure that you want to delete a remote branch "%s" on "%s"?: ',
            \ a:candidate.name,
            \ a:candidate.remote,
            \))
        call gita#throw('Cancel: Canceled by user')
      endif
    endif
    let args = [
          \ 'push',
          \ '--delete',
          \ a:candidate.remote,
          \ matchstr(a:candidate.name, '[^/]\+/\zs.*$'),
          \]
  else
    let args = [
          \ 'branch',
          \ options.force ? '-D' : '--delete',
          \ a:candidate.name,
          \]
  endif
  let git = gita#core#get_or_fail()
  call gita#process#execute(git, args)
  call gita#trigger_modified()
endfunction

function! s:action_refresh(candidate, options) abort
  let args = [
        \ 'remote',
        \ 'update',
        \ '--prune',
        \]
  let git = gita#core#get_or_fail()
  call gita#process#execute(git, args)
  call gita#trigger_modified()
endfunction

function! gita#action#branch#define(disable_mapping) abort
  call gita#action#define('branch:checkout', function('s:action_checkout'), {
        \ 'description': 'Checkout a branch',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['name'],
        \ 'options': {},
        \})
  call gita#action#define('branch:checkout:track', function('s:action_checkout'), {
        \ 'description': 'Checkout a branch (track)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['name'],
        \ 'options': { 'track': 1 },
        \})
  call gita#action#define('branch:rename', function('s:action_rename'), {
        \ 'description': 'Rename a branch',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['name'],
        \ 'options': {},
        \})
  call gita#action#define('branch:rename:force', function('s:action_rename'), {
        \ 'description': 'Rename a branch',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['name'],
        \ 'options': { 'force': 1 },
        \})
  call gita#action#define('branch:delete', function('s:action_delete'), {
        \ 'description': 'Delete a branch',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['name'],
        \ 'options': {},
        \})
  call gita#action#define('branch:delete:force', function('s:action_delete'), {
        \ 'description': 'Delete a branch',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['name'],
        \ 'options': { 'force': 1 },
        \})
  call gita#action#define('branch:refresh', function('s:action_refresh'), {
        \ 'description': 'Rebuild a list of branches in all remotes',
        \ 'mapping_mode': 'n',
        \ 'options': {},
        \})
  if a:disable_mapping
    return
  endif
  nmap <buffer><silent><expr><nowait> dd gita#action#smart_map('dd', '<Plug>(gita-branch-delete)')
  nmap <buffer><silent><expr><nowait> DD gita#action#smart_map('DD', '<Plug>(gita-branch-delete-force)')
  nmap <buffer><silent><expr><nowait> rr gita#action#smart_map('rr', '<Plug>(gita-branch-rename)')
  nmap <buffer><silent><expr><nowait> RR gita#action#smart_map('RR', '<Plug>(gita-branch-rename-force)')
  nmap <buffer><silent><expr><nowait> co gita#action#smart_map('co', '<Plug>(gita-branch-checkout)')
  nmap <buffer><silent><expr><nowait> ct gita#action#smart_map('co', '<Plug>(gita-branch-checkout-track)')
endfunction

