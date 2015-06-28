let s:save_cpo = &cpo
set cpo&vim


let s:D = gita#utils#import('Data.Dict')
let s:A = gita#utils#import('ArgumentParser')


let s:parser = s:A.new({
      \ 'name': 'Gita add',
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
  let gita = gita#core#get()
  let statuses = gita.get_parsed_status()
  let candidates = deepcopy(extend(
        \ get(statuses, 'unstaged', []),
        \ get(statuses, 'untracked', []),
        \))
  let candidates = filter(
        \ map(candidates, 'get(v:val, ''path'', '''')'),
        \ 'len(v:val) && index(a:options.__unknown__, v:val) == -1',
        \)
  let candidates = extend(
        \ a:candidates,
        \ candidates,
        \)
  return candidates
endfunction " }}}


function! gita#features#add#exec(...) abort " {{{
  let gita = gita#core#get()
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  if !empty(get(options, '--', []))
    call map(options['--'], 'gita#utils#expand(v:val)')
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
    let options = extend(options, {
          \ '--': options.__unknown__,
          \})
    call gita#features#add#exec(options)
  endif
endfunction " }}}
function! gita#features#add#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
