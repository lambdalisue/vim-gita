let s:save_cpo = &cpo
set cpo&vim

let s:D = gita#utils#import('Data.Dict')
let s:B = gita#utils#import('VCS.Git.BlameParser')
let s:A = gita#utils#import('ArgumentParser')


let s:const = {}
let s:const.filetype = 'gita-blame'


function! s:complete_commit(arglead, cmdline, cursorpos, ...) abort " {{{
  let leading = matchstr(a:arglead, '^.*\.\.\.\?')
  let arglead = substitute(a:arglead, '^.*\.\.\.\?', '', '')
  let candidates = call('gita#completes#complete_local_branch', extend(
        \ [arglead, a:cmdline, a:cursorpos],
        \ a:000,
        \))
  let candidates = map(candidates, 'leading . v:val')
  return candidates
endfunction " }}}
let s:parser = s:A.new({
      \ 'name': 'Gita[!] blame',
      \ 'description': 'Show what revision and author last modified each line of a file.',
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
      \ 'file', [
      \   'A filepath which you want to blame.',
      \   'If it is omitted and the current buffer is a file',
      \   'buffer, the current buffer will be used.',
      \ ],
      \)

function! gita#features#blame#exec(...) abort " {{{
  let gita = gita#get()
  let options = deepcopy(get(a:000, 0, {}))
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  if has_key(options, 'commit')
    let options.commit = substitute(options.commit, 'INDEX', '', 'g')
  endif
  if has_key(options, 'file')
    let options['--'] = [options.file]
    unlet! options.file
  endif
  if !empty(get(options, '--', []))
    call map(options['--'], 'gita#utils#expand(v:val)')
  endif
  let options = s:D.pick(options, [
        \ '--',
        \ 'porcelain',
        \ 'commit',
        \])
  return gita.operations.blame(options, config)
endfunction " }}}
function! gita#features#blame#show(...) abort " {{{
  let options = get(a:000, 0, {})
  " ensure file option
  if empty(get(options, 'file', ''))
    if !empty(&buftype) && empty(get(b:, '_gita_original_filename'))
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
  let options.file = gita#utils#expand(options.file)
  " ensure commit
  if empty(get(options, 'commit', ''))
    let options.commit = ''
  endif

  let options.porcelain = 1
  let result = gita#features#blame#exec(options, {
        \ 'echo': 'fail',
        \})
  if result.status != 0
    return
  endif
  let chunks = s:B.parse(result.stdout, { 'fail_silently': !g:gita#debug })
  let linechunks = []
  let NAVI = []
  let VIEWER = []
  for chunk in chunks
    let n = max([2, len(chunk.contents)])
    let navi = [
          \ chunk.summary,
          \ printf('%s, %s',
          \   chunk.revision[:7],
          \   strftime('%Y-%m-%d', chunk.author_time),
          \ ),
          \]
    for i in range(n)
      call add(linechunks, chunk)
      call add(NAVI, get(navi, i, ''))
      call add(VIEWER, get(chunk.contents, i, ''))
    endfor
    call add(NAVI, repeat('.', 150))
    call add(VIEWER, repeat('.', 150))
  endfor

  let NAVI_bufname = gita#utils#buffer#bufname(
        \ options.file,
        \ 'BLAME',
        \ 'NAVI',
        \ options.commit,
        \)
  let VIEWER_bufname = gita#utils#buffer#bufname(
        \ options.file,
        \ 'BLAME',
        \ 'VIEWER',
        \ options.commit,
        \)
  let bufnums = gita#utils#buffer#open2(
        \ VIEWER_bufname, NAVI_bufname, 'gita_blame', {
        \   'opener': get(options, 'opener', 'tabedit'),
        \   'opener2': get(options, 'opener2', 'topleft 50 vsplit'),
        \   'range': get(options, 'range', 'all'),
        \})
  let VIEWER_bufnum = bufnums.bufnum1
  let NAVI_bufnum = bufnums.bufnum2

  " VIEWER
  execute printf('%swincmd w', bufwinnr(VIEWER_bufnum))
  call gita#utils#buffer#update(VIEWER)
  silent execute printf("setlocal filetype=%s", &l:filetype)
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setlocal nomodifiable readonly
  setlocal scrollbind cursorbind
  setlocal scrollopt=ver,jump
  setlocal nowrap
  setlocal nofoldenable
  setlocal foldcolumn=0
  let b:_gita_blame_linechunks = linechunks
  let b:_gita_original_filename = options.file

  " NAVI
  execute printf('%swincmd w', bufwinnr(NAVI_bufnum))
  call gita#utils#buffer#update(NAVI)
  silent execute printf("setlocal filetype=%s", s:const.filetype)
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setlocal nomodifiable readonly
  setlocal scrollbind cursorbind
  setlocal scrollopt=ver,jump
  setlocal nowrap
  setlocal nofoldenable
  setlocal nolist
  setlocal nonumber
  setlocal foldcolumn=0
  setlocal virtualedit=onemore
  let b:_gita_blame_linechunks = linechunks
  let b:_gita_original_filename = options.file
endfunction " }}}
function! gita#features#blame#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    call gita#features#blame#show(options)
  endif
endfunction " }}}
function! gita#features#blame#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
