let s:V = gita#vital()
let s:Prompt = s:V.import('Vim.Prompt')

function! s:action_checkout(candidate, options) abort
  let options = extend({
        \ 'track': 0,
        \}, a:options)
  if a:candidate.is_remote
    let name = substitute(a:candidate.name, '^origin/', '', '')
    let args = [
          \ '-b' . name,
          \ empty(options.track) ? '' : '--track',
          \ a:candidate.name,
          \]
  else
    let args = [a:candidate.name]
  endif
  let git = gita#core#get_or_fail()
  call gita#process#execute(git, ['checkout'] + args, { 'quiet': 1 })
  call gita#trigger_modified()
endfunction

function! s:action_rename(candidate, options) abort
  let options = extend({
        \ 'force': 0,
        \}, a:options)
  let newname = s:Prompt.ask(
        \ printf('Please input a new branch name of "%s": ', a:candidate.name),
        \ a:candidate.name,
        \)
  if empty(newname)
    call gita#throw('Cancel')
  endif
  let args = [
        \ 'branch',
        \ options.force ? '-M' : '--move',
        \ a:candidate.name,
        \ newname,
        \]
  let git = gita#core#get_or_fail()
  call gita#process#execute(git, ['branch'] + args, { 'quiet': 1 })
  call gita#trigger_modified()
endfunction

function! s:action_delete(candidate, options) abort
  let options = extend({
        \ 'force': 0,
        \}, a:options)
  let args = [
        \ 'branch',
        \ options.force ? '-D' : '--delete',
        \ a:candidate.name,
        \]
  let git = gita#core#get_or_fail()
  call gita#process#execute(git, ['branch'] + args, { 'quiet': 1 })
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
        \ 'description': 'Rename a branch',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['name'],
        \ 'options': {},
        \})
  call gita#action#define('branch:delete:force', function('s:action_delete'), {
        \ 'description': 'Rename a branch',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['name'],
        \ 'options': { 'force': 1 },
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

