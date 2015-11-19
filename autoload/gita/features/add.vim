let s:save_cpoptions = &cpoptions
set cpoptions&vim


let s:D = gita#import('Data.Dict')
let s:L = gita#import('Data.List')
let s:A = gita#import('ArgumentParser')


let s:parser = s:A.new({
      \ 'name': 'Gita[!] add',
      \ 'description': 'Add file contents to the index',
      \})
call s:parser.add_argument(
      \ '--verbose', '-v',
      \ 'Be verbose.',
      \)
call s:parser.add_argument(
      \ '--force', '-f',
      \ 'Allow adding otherwise ignored files.',
      \)
call s:parser.add_argument(
      \ '--update', '-u', [
      \   'Update the index just where it already has an entry matching <pathspec>.',
      \   'This removes as well as modifies index entries to match the working tree,',
      \   'but adds no new files.',
      \   'If no <pathspec> is given when -u option is used, all tracked files in the',
      \   'entire working tree are updated.',
      \ ]
      \)
call s:parser.add_argument(
      \ '--all', '-A', [
      \   'Update the index not only where the working tree has a file matching <pathspec>',
      \   'but also where the index already has an entry. This adds, modifies, and removes',
      \   'index entries to match the working tree.',
      \   'If no <pathspec> is given when -A option is used, all files in the entire working',
      \   'tree are updated.',
      \ ], {
      \   'deniable': 1,
      \   'configlicts': ['ignore-removal'],
      \})
call s:parser.add_argument(
      \ '--ignore-removal', [
      \   'Update the index by adding new files that are unknown to the index and files modified',
      \   'in the working tree, but ignore files that have been removed from the working tree.',
      \   'This option is a no0op when no <pathspec> is used.',
      \ ], {
      \   'deniable': 1,
      \   'configlicts': ['all'],
      \})
call s:parser.add_argument(
      \ '--ignore-errors', [
      \ 'If some files could not be added because of errors indexing them, do not abort the operation,',
      \ 'but continue adding the others. The command shall still exit with non-zero status.',
      \])
function! s:parser.hooks.post_complete_optional_argument(candidates, options) abort " {{{
  let candidates = s:L.flatten([
        \ gita#utils#completes#complete_unstaged_files('', '', [0, 0], a:options),
        \ gita#utils#completes#complete_untracked_files('', '', [0, 0], a:options),
        \ a:candidates,
        \])
  return candidates
endfunction " }}}

function! gita#features#add#exec(...) abort " {{{
  let gita = gita#get()
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  if !empty(get(options, '--', []))
    " git understand REAL/UNIX path in working tree
    let options['--'] = gita#utils#path#real_abspath(options['--'])
  endif
  let options = s:D.pick(options, [
        \ '--',
        \ 'v', 'verbose',
        \ 'f', 'force',
        \ 'A', 'all',
        \ 'ignore-removal',
        \ 'ignore-errors',
        \])
  return gita.operations.add(options, config)
endfunction " }}}
function! gita#features#add#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let options = extend(
          \ deepcopy(g:gita#features#add#default_options),
          \ options)
    if !empty(options.__unknown__)
      let options['--'] = options.__unknown__
    endif
    call gita#action#exec('add', options.__range__, options, { 'echo': 'both' })
  endif
endfunction " }}}
function! gita#features#add#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}
function! gita#features#add#action(candidates, options, config) abort " {{{
  if empty(a:candidates)
    return
  endif
  let options = extend({
        \ '--': map(a:candidates, 'get(v:val, "realpath", v:val.path)'),
        \ 'ignore_errors': 1,
        \}, a:options)
  call gita#features#add#exec(options, extend({
        \ 'echo': 'fail',
        \}, a:config))
endfunction " }}}


let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
