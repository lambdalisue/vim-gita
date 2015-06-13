let s:save_cpo = &cpo
set cpo&vim


let s:D = gita#utils#import('Data.Dict')
let s:A = gita#utils#import('ArgumentParser')


" Private
function! s:get_parser() abort " {{{
  if !exists('s:parser') || get(g:, 'gita#debug', 0)
    let s:parser = s:A.new({
          \ 'name': 'Gita reset',
          \ 'description': 'Reset current HEAD to the specified state',
          \})
    call s:parser.add_argument(
          \ '--verbose', '-v', [
          \ 'Be verbose.',
          \])
    call s:parser.add_argument(
          \ '--soft', [
          \   'Does not touch the index file or the working tree at all (but resets the head to <commit>, just like all modes do).',
          \   'This leaves all your changed files "Changes to be committed", as git status would put it.',
          \], {
          \   'configlicts': ['mixed', 'hard', 'merge', 'keep'],
          \})
    call s:parser.add_argument(
          \ '--mixed', [
          \   'Resets the index but not the working tree (i.e., the changed files are preserved but not marked for commit) and reports',
          \   'what has not been updated. This is the default action.',
          \], {
          \   'configlicts': ['soft', 'hard', 'merge', 'keep'],
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
          \   'configlicts': ['soft', 'mixed', 'merge', 'keep'],
          \})
    call s:parser.add_argument(
          \ '--merge', [
          \   'Resets the index and updates the files in the working tree that are different between <commit> and HEAD, but keeps those which are',
          \   'different between the index and working tree (i.e. which have changes which have not been added). If a file that is different',
          \   'between <commit> and the index has unstaged changes, reset is aborted.',
          \], {
          \   'configlicts': ['soft', 'mixed', 'hard', 'keep'],
          \})
    call s:parser.add_argument(
          \ '--keep', [
          \   'Resets index entries and updates files in the working tree that are different between <commit> and HEAD.',
          \   'If a file that is different between <commit> and HEAD has local changes, reset is aborted.',
          \], {
          \   'configlicts': ['soft', 'mixed', 'hard', 'merge'],
          \})

    " A hook function to convert 'verbose' to 'quiet'
    function! s:parser.hooks.post_validate(opts) abort
      if !get(a:opts, 'verbose', 0)
        let a:opts.quiet = 1
      else
        unlet a:opts.verbose
      endif
    endfunction
    " A hook function to display staged files in completions
    function! s:parser.hooks.post_complete_optionional_argument(candidates, options) abort
      let gita = s:get_gita()
      let statuses = gita.get_parsed_status()
      let candidates = deepcopy(
            \ get(statuses, 'staged', []),
            \)
      let candidates = filter(
            \ map(candidates, 'get(v:val, ''path'', '''')'),
            \ 'len(v:val) && index(a:options.__unknown__, v:val) == -1',
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


function! gita#features#reset#exec(...) abort " {{{
  let gita = gita#core#get()
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
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
  let options = s:D.pick(options, [
        \ '--',
        \ 'q', 'quiet',
        \ 'soft',
        \ 'mixed',
        \ 'N',
        \ 'hard',
        \ 'merge',
        \ 'keep',
        \])
  return gita.operations.reset(options, config)
endfunction " }}}
function! gita#features#reset#action(statuses, options) abort " {{{
  if empty(a:statuses)
    return
  endif
  let options = extend({
        \ '--': map(deepcopy(a:statuses), 'v:val.path'),
        \}, a:options)
  call gita#features#reset#exec(options, {
        \ 'echo': 'fail',
        \})
endfunction " }}}
function! gita#features#reset#command(bang, range, ...) abort " {{{
  let parser = s:get_parser()
  let options = parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let result = gita#features#reset#exec(extend({
          \ '--': get(options, '__unknown__', []),
          \}, options))
    if len(result.stdout)
      call gita#utils#infomsg(result.stdout)
    endif
  endif
endfunction " }}}
function! gita#features#reset#complete(arglead, cmdline, cursorpos) abort " {{{
  let parser = s:get_parser()
  let candidates = parser.complete(a:arglead, a:cmdline, a:cursorpos)
  return candidates
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
