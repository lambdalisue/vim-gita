let s:save_cpo = &cpo
set cpo&vim


let s:D = gita#utils#import('Data.Dict')
let s:A = gita#utils#import('ArgumentParser')


let s:parser = s:A.new({
      \ 'name': 'Gita diff',
      \ 'description': 'Show a difference of a file',
      \})
call s:parser.add_argument(
      \ 'revision', [
      \   'A revision (e.g. HEAD) which you want to compare with.',
      \ ], {
      \   'complete': function('gita#completes#complete_local_branch'),
      \ })
call s:parser.add_argument(
      \ 'file', [
      \   'A filepath which you want to diff the content.',
      \   'If it is omitted and the current buffer is a file',
      \   'buffer, the current buffer will be used.',
      \ ],
      \)
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
  if !gita.enabled
    redraw
    call gita#utils#warn(
          \ 'Gita is not available in the current buffer.',
          \)
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
        \ 'commit',
        \])
  return gita.operations.diff(options, config)
endfunction " }}}
function! gita#features#diff#show(...) abort " {{{
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if get(options, 'single')
    call gita#features#diff#single(options, config)
  elseif get(options, 'double')
    call gita#features#diff#double(options, config)
  else
    throw 'vim-gita: "single" nor "double" is specified.'
  endif
endfunction " }}}
function! gita#features#diff#single(...) abort " {{{
  let gita = gita#core#get()
  if !gita.enabled
    redraw
    call gita#utils#warn(
          \ 'Gita is not available in the current buffer.',
          \)
    return
  endif
  let options = extend({
        \ 'ignore_submodules': 1,
        \ 'no_prefix': 1,
        \ 'no_color': 1,
        \ 'unified': '0',
        \ 'histogram': 1,
        \}, get(a:000, 0, {}))
  " automatically specify the current buffer if nothing is specified
  " and the buffer is a file buffer
  if empty(get(options, 'file', ''))
    if !empty(&buftype)
      call gita#utils#error(
            \ 'The current buffer is not a file buffer.',
            \)
      call gita#utils#info(
            \ 'Operation has canceled.'
            \)
      return
    endif
    let options.file = '%'
  endif
  let options.file = expand(options.file)
  let options.file = gita.git.get_relative_path(options.file)
  " Ask if no revision is specified.
  if !gita#features#show#_ensure_revision(options, 'INDEX')
    return
  endif
  let relpath = gita.git.get_relative_path(options.file)
  let options = extend(
        \ s:D.omit(options, ['revision', 'file']), {
        \  'commit': options.revision,
        \  '--': [options.file],
        \ })
  let config = extend({
        \ 'echo': 'fail',
        \}, get(a:000, 1, {}))
  let result = gita#features#diff#exec(options, config)
  if result.status != 0
    return
  endif

  let DIFF = split(result.stdout, '\v\r?\n')
  let DIFF_bufname = gita#utils#buffer#bufname(
        \ printf('%s.diff', relpath),
        \ empty(options.commit) ? 'INDEX' : options.commit,
        \)
  let opener = get(options, 'opener', 'edit')
  call gita#utils#buffer#open(DIFF_bufname, '', {
        \ 'opener': opener,
        \})
  call gita#utils#buffer#update(DIFF)
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setlocal nomodifiable
endfunction " }}}
function! gita#features#diff#double(...) abort " {{{
  let gita = gita#core#get()
  if !gita.enabled
    redraw
    call gita#utils#warn(
          \ 'Gita is not available in the current buffer.',
          \)
    return
  endif

  let options = get(a:000, 0, {})
  let config = extend({
        \ 'echo': '',
        \}, get(a:000, 1, {}))
  let result = gita#features#show#exec(options, config)
  if result.status != 0
    let REF = split(result.stdout, '\v\r?\n')
  else
    " probably the file does not exists in the version
    " so just show a empty buffer
    let REF = []
  endif
  " Note:
  "   options.file and options.revision will be configured by
  "   gita#features#show#exec
  let abspath = gita.git.get_absolute_path(options.file)
  let relpath = gita.git.get_relative_path(options.file)

  let LOCAL_bufname = abspath
  let REF_bufname = gita#utils#buffer#bufname(
        \ relpath,
        \ empty(options.revision) ? 'INDEX' : options.revision,
        \)
  " Open two buffers
  let bufnums = gita#utils#buffer#diff2(
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

  " LOCAL
  execute printf('%swincmd w', bufwinnr(LOCAL_bufnum))
  diffupdate
endfunction " }}}
function! gita#features#diff#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    call gita#features#diff#show(options)
  endif
endfunction " }}}
function! gita#features#diff#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
