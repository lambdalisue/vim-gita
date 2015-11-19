let s:save_cpoptions = &cpoptions
set cpoptions&vim


let s:L = gita#import('Data.List')
let s:D = gita#import('Data.Dict')
let s:A = gita#import('ArgumentParser')


function! s:complete_commit(arglead, cmdline, cursorpos, ...) abort " {{{
  let candidates = call('gita#utils#completes#complete_local_branch', extend(
        \ [a:arglead, a:cmdline, a:cursorpos], a:000,
        \))
  return extend(['HEAD'], candidates)
endfunction " }}}
let s:parser = s:A.new({
      \ 'name': 'Gita[!] reset',
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
call s:parser.add_argument(
      \ 'commit', [
      \   'A commit-ish which you want to show. The followings are Gita special terms:',
      \ ], {
      \   'complete': function('s:complete_commit'),
      \})
function! s:parser.hooks.post_validate(options) abort " {{{
  if !get(a:options, 'verbose', 0)
    let a:options.quiet = 1
  else
    unlet a:options.verbose
  endif
endfunction " }}}
function! s:parser.hooks.post_complete_optionional_argument(candidates, options) abort " {{{
  let candidates = s:L.flatten([
        \ gita#utils#completes#complete_staged_files('', '', [0, 0], a:options),
        \ a:candidates,
        \])
  return candidates
endfunction " }}}
 
 
function! gita#features#reset#exec(...) abort " {{{
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
        \ 'q', 'quiet',
        \ 'soft',
        \ 'mixed',
        \ 'N',
        \ 'hard',
        \ 'merge',
        \ 'keep',
        \ 'commit',
        \])
  return gita.operations.reset(options, config)
endfunction " }}}
function! gita#features#reset#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let options = extend(
          \ deepcopy(g:gita#features#reset#default_options),
          \ options)
    let options['--'] = options.__unknown__
    call gita#action#exec('reset', options.__range__, options, { 'echo': 'both' })
  endif
endfunction " }}}
function! gita#features#reset#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}
function! gita#features#reset#action(candidates, options, config) abort " {{{
  if empty(a:candidates)
    return
  endif
  let options = extend({
        \ '--': map(a:candidates, 'v:val.path'),
        \ 'quiet': 1,
        \}, a:options)
  call gita#features#reset#exec(options, extend({
        \ 'echo': 'fail',
        \}, a:config))
endfunction " }}}


let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
