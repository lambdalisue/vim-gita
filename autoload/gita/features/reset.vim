let s:save_cpo = &cpo
set cpo&vim


let s:A = gita#utils#import('ArgumentParser')


" Private
function! s:get_parser() abort " {{{
  if !exists('s:parser') || get(g:, 'gita#debug', 0)
    let s:parser = s:A.new({
          \ 'name': 'Gita reset',
          \ 'description': 'Reset current HEAD to the specified state',
          \})
    call s:parser.add_argument(
          \ '--quiet', '-q', [
          \   'Quiet',
          \], {
          \   'default': 1,
          \   'deniable': 1,
          \})
    call s:parser.add_argument(
          \ '--soft', [
          \   'Does not touch the index file or the working tree at all (but resets the head to <commit>, just like all modes do).',
          \   'This leaves all your changed files "Changes to be committed", as git status would put it.',
          \], {
          \   'conflicts': ['mixed', 'hard', 'merge', 'keep'],
          \})
    call s:parser.add_argument(
          \ '--mixed', [
          \   'Resets the index but not the working tree (i.e., the changed files are preserved but not marked for commit) and reports',
          \   'what has not been updated. This is the default action.',
          \], {
          \   'conflicts': ['soft', 'hard', 'merge', 'keep'],
          \})
    call s:parser.add_argument(
          \ '-N', [
          \   'If this is specified, removed paths are marked as intent-to-add.'
          \], {
          \   'superordinates': ['mixed'],
          \})
    call s:parser.add_argument(
          \ '--hard', [
          \   'Resets the index and working tree. Any changes to tracked files in the working tree since <commit> are discarded.',
          \], {
          \   'conflicts': ['soft', 'mixed', 'merge', 'keep'],
          \})
    call s:parser.add_argument(
          \ '--merge', [
          \   'Resets the index and updates the files in the working tree that are different between <commit> and HEAD, but keeps those which are',
          \   'different between the index and working tree (i.e. which have changes which have not been added). If a file that is different',
          \   'between <commit> and the index has unstaged changes, reset is aborted.',
          \], {
          \   'conflicts': ['soft', 'mixed', 'hard', 'keep'],
          \})
    call s:parser.add_argument(
          \ '--keep', [
          \   'Resets index entries and updates files in the working tree that are different between <commit> and HEAD.',
          \   'If a file that is different between <commit> and HEAD has local changes, reset is aborted.',
          \], {
          \   'conflicts': ['soft', 'mixed', 'hard', 'merge'],
          \})

    " A hook function to display staged files in completions
    function! s:parser.hooks.post_complete_optional_argument(candidates, opts) abort
      let gita = s:get_gita()
      let statuses = gita.get_parsed_status()
      let candidates = deepcopy(
            \ get(statuses, 'staged', []),
            \)
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
  endif
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
  return gita.operations.reset(options)
endfunction " }}}


" Internal API
function! gita#features#reset#exec(...) abort " {{{
  return call('s:exec', a:000)
endfunction " }}}


" External API
function! gita#features#reset#command(bang, range, ...) abort " {{{
  let parser = s:get_parser()
  let options = parser.parse(a:bang, a:range, get(a:000, 0, ''))
  let options['--'] = get(options, '__unknown__', [])
  let result = s:exec(options)
  if len(result.stdout)
    call gita#utils#infomsg(result.stdout)
  endif
endfunction " }}}
function! gita#features#reset#complete(arglead, cmdline, cursorpos) abort " {{{
  let parser = s:get_parser()
  let candidates = parser.complete(a:arglead, a:cmdline, a:cursorpos)
  return candidates
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
