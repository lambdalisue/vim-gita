let s:save_cpo = &cpo
set cpo&vim


let s:D = gita#utils#import('Data.Dict')
let s:A = gita#utils#import('ArgumentParser')


function! s:complete_commit(arglead, cmdline, cursorpos, ...) abort " {{{
  let arglead = substitute(a:arglead, '^.*\.\.\.\?', '', '')
  return call('gita#completes#complete_local_branch', extend(
        \ [arglead, a:cmdline, a:cursorpos],
        \ a:000,
        \))
endfunction " }}}
let s:parser = s:A.new({
      \ 'name': 'Gita diff',
      \ 'description': 'Show changes between commits, commit and working tree, etc',
      \})
call s:parser.add_argument(
      \ 'commit', [
      \   'A commit which you want to compare with.',
      \   'If nothing is specified, it show changes in working tree relative to the index (staging area for next commit).',
      \   'If <commit> is specified, it show changes in working tree relative to the named <commit>.',
      \   'If <commit>..<commit> is specified, it show the changes between two arbitrary <commit>.',
      \   'If <commit>...<commit> is specified, it show thechanges on the branch containing and up to the second <commit>, starting at a common ancestor of both <commit>.',
      \ ], {
      \   'complete': function('s:complete_commit'),
      \ })
call s:parser.add_argument(
      \ '--no-index',
      \ 'Compare the given two paths on the filesystem.', {
      \   'conflicts': ['cached'],
      \ })
call s:parser.add_argument(
      \ '--cached',
      \ 'Compare the changes you staged for the next commit relative to the named <commit> or HEAD', {
      \   'conflicts': ['no_index'],
      \ })
call s:parser.add_argument(
      \ '--single', '-1',
      \ 'Open a single buffer to show the difference', {
      \   'conflicts': ['double'],
      \ })
call s:parser.add_argument(
      \ '--double', '-2',
      \ 'Open double buffers to compare the difference', {
      \   'conflicts': ['single'],
      \ })
call s:parser.add_argument(
      \ '--opener', '-o', [
      \   'A way to open a new buffer such as "edit", "split", or etc.',
      \ ], {
      \ 'type': s:A.types.value,
      \ },
      \)
call s:parser.add_argument(
      \ '--vertical', '-v', [
      \   'Vertically open a second buffer (vsplit).',
      \   'If it is omitted, the buffer is opened horizontally (split).',
      \ ], {
      \ 'superordinates': ['double'],
      \ },
      \)
function! s:parser.hooks.pre_validate(options) abort " {{{
  " Automatically use '--singe' if no conflicted argument is specified
  if empty(self.get_conflicted_arguments('single', a:options))
    let a:options.single = 1
  endif
endfunction " }}}


function! gita#features#diff#exec(...) abort " {{{
  let gita = gita#core#get()
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  if !empty(get(options, '--', []))
    call map(options['--'], 'expand(v:val)')
  endif
  let options = s:D.pick(options, [
        \ '--',
        \ 'ignore_submodules',
        \ 'no_prefix',
        \ 'no_color',
        \ 'unified',
        \ 'histogram',
        \ 'no_index',
        \ 'cached',
        \ 'commit',
        \])
  return gita.operations.diff(options, config)
endfunction " }}}
function! gita#features#diff#show(...) abort " {{{
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if get(options, 'single')
    call gita#features#diff#show_single(options, config)
  elseif get(options, 'double')
    call gita#features#diff#show_double(options, config)
  else
    throw 'vim-gita: "single" nor "double" is specified.'
  endif
endfunction " }}}
function! gita#features#diff#show_single(...) abort " {{{
  let gita = gita#core#get()
  let options = get(a:000, 0, {})
  if gita.fail_on_disabled()
    return
  endif
  let options.no_prefix = 1
  let options.no_color = 1
  let options.unified = '0'
  let options.histogram = 1

  let result = gita#features#diff#exec(options, {
        \ 'echo': 'fail',
        \})
  if result.status != 0
    return
  endif

  if len(get(options, '--', [])) == 1
    let DIFF_bufname = gita#utils#buffer#bufname(
          \ printf('%s.diff', options['--'][0]),
          \ empty(options.commit) ? 'INDEX' : options.commit,
          \)
  else
    let DIFF_bufname = gita#utils#buffer#bufname(
          \ 'diff',
          \ empty(options.commit) ? 'INDEX' : options.commit,
          \)
  endif
  let DIFF = split(result.stdout, '\v\r?\n')
  let opener = get(options, 'opener', 'edit')
  call gita#utils#buffer#open(DIFF_bufname, '', {
        \ 'opener': opener,
        \})
  call gita#utils#buffer#update(DIFF)
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setlocal nomodifiable
  setlocal filetype=diff
endfunction " }}}
function! gita#features#diff#show_double(...) abort " {{{
  let gita = gita#core#get()
  let options = get(a:000, 0, {})
  if gita.fail_on_disabled()
    return
  endif

  if len(get(options, '--', [])) == 0
    " Use a current buffer
    let options['--'] = ['%']
  elseif len(get(options, '--', [])) > 1
    call gita#utils#warn(
          \ 'A single file required to be specified to compare the difference.',
          \)
    return
  elseif match(get(options, 'commit', ''), '^.*\.\.\.\?.*$') != -1
    call gita#utils#warn(
          \ '<commit>..<commit> or <commit>...<commit> style is not supported and',
          \ 'a single <commit> is required to be specified to compare the difference.',
          \)
    return
  endif
  let options.file = expand(options['--'][0])
  let options.object = printf('%s:%s',
        \ options.commit,
        \ options.file,
        \)
  let result = gita#features#show#exec(options, {
        \ 'echo': '',
        \})
  if result.status == 0
    let REF = split(result.stdout, '\v\r?\n')
  else
    " probably the file does not exists in the version
    " so just show a empty buffer
    let REF = []
  endif
  let abspath = gita.git.get_absolute_path(options.file)
  let relpath = gita.git.get_relative_path(options.file)

  let LOCAL_bufname = abspath
  let REF_bufname = gita#utils#buffer#bufname(
        \ relpath,
        \ empty(options.commit) ? 'INDEX' : options.commit,
        \)
  " Open two buffers
  let bufnums = gita#utils#buffer#open2(
        \ LOCAL_bufname, REF_bufname, 'diff', {
        \   'opener': get(options, 'opener', 'edit'),
        \   'vertical': get(options, 'vertical', 0),
        \})
  let LOCAL_bufnum = bufnums.bufnum1
  let REF_bufnum   = bufnums.bufnum2

  " REFERENCE
  execute printf('%swincmd w', bufwinnr(REF_bufnum))
  call gita#utils#buffer#update(REF)
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setlocal nomodifiable
  diffthis

  " LOCAL
  execute printf('%swincmd w', bufwinnr(LOCAL_bufnum))
  diffthis
  diffupdate
endfunction " }}}
function! gita#features#diff#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    if !has_key(options, 'commit')
      let commit = gita#utils#ask(
            \ 'Which commit do you want to compare with? ',
            \ 'INDEX',
            \)
      if empty(commit)
        call gita#utils#warn(
              \ 'The operation has canceled by user',
              \)
        return
      endif
      let options.commit = commit
    endif
    let options.commit = substitute(options.commit, '^INDEX$', '', '')
    let options = extend(options, {
          \ '--': options.__unknown__,
          \})
    call gita#features#diff#show(options)
  endif
endfunction " }}}
function! gita#features#diff#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
