leta s:save_cpo = &cpo
set cpo&vim


let s:A = gita#utils#import('ArgumentParser')


" Private
function! s:get_parser() abort " {{{
  if exists('s:parser') && !get(g:, 'gita#debug', 0)
    return s:parser
  endif
  let s:parser = s:A.new({
        \ 'name': 'Gita add',
        \ 'description': 'Add file contents to the index',
        \})
  call s:parser.add_argument(
        \ '--dry-run', '-n',
        \ 'Don''t actually add the file(s), just show if they exist and/or will be ignored.',
        \)
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
        \   'conflicts': ['ignore_removal'],
        \})
  call s:parser.add_argument(
        \ '--ignore-removal', [
        \   'Update the index by adding new files that are unknown to the index and files modified',
        \   'in the working tree, but ignore files that have been removed from the working tree.',
        \   'This option is a no0op when no <pathspec> is used.',
        \ ], {
        \   'deniable': 1,
        \   'conflicts': ['ignore_removal'],
        \})
  call s:parser.add_argument(
        \ '--refresh',
        \ 'Don''t add the file(s), but only refresh their stat() information in the index.',
        \)
  call s:parser.add_argument(
        \ '--ignore-errors', [
        \ 'If some files could not be added because of errors indexing them, do not abort the operation,',
        \ 'but continue adding the others. The command shall still exit with non-zero status.',
        \])
  call s:parser.add_argument(
        \ '--ignore-missings', [
        \ 'This option can only be used together with --dry-run. By using this option the user can',
        \ 'check if any of the given files would be ignored, no matter if they are already present',
        \ 'in the work tree or not.',
        \])

  " A hook function to display unstaged/untracked files in completions
  function! s:parser.hooks.post_complete_optional_argument(candidates, opts) abort
    let gita = s:get_gita()
    let statuses = gita.get_parsed_status()
    let candidates = deepcopy(extend(
          \ get(statuses, 'unstaged', []),
          \ get(statuses, 'untracked', []),
          \))
    let candidates = filter(
          \ map(candidates, 'get(v:val, ''path'', '''')'),
          \ 'len(v:val) && index(a:opts.__unknown__, v:val) == -1',
          \)
    let candidates = extend(
          \ a:candidates,
          \ candidates,
          \)
    return candidates
  endfunction
  return s:parser
endfunction " }}}
function! s:get_gita(...) abort " {{{
  return call('gita#core#get', a:000)
endfunction " }}}
function! s:exec(...) abort " {{{
  let gita = s:get_gita()
  let options = get(a:000, 0, {})
  " automatically specify the current buffer if nothing is specified
  " and the buffer is a file buffer
  if empty(&buftype) && empty(get(options, '--', []))
    let options['--'] = ['%']
  endif
  if !gita.enabled
    redraw
    call gita#utils#warn(
          \ 'Gita is not available in the current buffer.',
          \)
    call gita#utils#debugmsg(
          \ 'gita#features#add#s:exec',
          \ printf('bufname: "%s"', bufname('%')),
          \ printf('cwd: "%s"', getcwd()),
          \ printf('gita: "%s"', string(gita)),
          \)
    return
  endif
  return gita.operations.add(options)
endfunction " }}}


" Internal API
function! gita#features#add#exec(...) abort " {{{
  return call('s:exec', a:000)
endfunction " }}}


" External API
function! gita#features#add#command(bang, range, ...) abort " {{{
  let parser = s:get_parser()
  let options = parser.parse(a:bang, a:range, get(a:000, 0, ''))
  let options['--'] = get(options, '__unknown__', [])
  let result = s:exec(options)
  if len(result.stdout)
    call gita#utils#infomsg(result.stdout)
  endif
endfunction " }}}
function! gita#features#add#complete(arglead, cmdline, cursorpos) abort " {{{
  let parser = s:get_parser()
  let candidates = parser.complete(a:arglead, a:cmdline, a:cursorpos)
  return candidates
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
