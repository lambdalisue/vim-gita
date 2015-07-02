let s:save_cpo = &cpo
set cpo&vim

let s:L = gita#utils#import('Data.List')
let s:D = gita#utils#import('Data.Dict')
let s:S = gita#utils#import('Data.String')
let s:B = gita#utils#import('VCS.Git.BlameParser')
let s:A = gita#utils#import('ArgumentParser')


let s:const = {}
let s:const.filetype = 'gita-blame'

sign define GitaHorizontalSign
      \ texthl=SignColumn
      \ linehl=GitaHorizontal


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

function! s:create_chunks(blameobj) abort " {{{
  let previous_revision = ''
  let chunks = []
  for lineinfo in a:blameobj.lineinfos
    if previous_revision !=# lineinfo.revision
      let previous_revision = lineinfo.revision
      let chunk = extend(
            \ deepcopy(lineinfo),
            \ deepcopy(a:blameobj.revisions[previous_revision]),
            \)
      unlet chunk.contents
      let chunk.contents = [lineinfo.contents]
      call add(chunks, chunk)
    else
      let chunk = chunks[-1]
      call add(chunk.contents, lineinfo.contents)
    endif
  endfor
  return chunks
endfunction " }}}
function! s:format_chunk(chunk, ...) abort " {{{
  let width = get(a:000, 0, winwidth(0))
  let wrap = get(a:000, 1, 0)
  if wrap
    let summary = map(
          \ s:S.wrap(a:chunk.summary, width - 1),
          \ 'substitute(v:val, ''\v%(^\s+|\s+$)'', "", "g")',
          \)
  else
    let summary = s:S.truncate_skipping(
          \ a:chunk.summary,
          \ width - 2,
          \ 3,
          \ '...',
          \)
  endif
  let revision = a:chunk.revision[:7]
  let author = a:chunk.author
  let timestr = gita#utils#format_timestamp(
        \ a:chunk.author_time,
        \ a:chunk.author_tz,
        \ '', 'on ',
        \)
  let author_info = printf('%s authored %s', author, timestr)
  let formatted = s:L.flatten([
        \ summary,
        \ printf('%s%s%s',
        \   author_info,
        \   repeat(' ', width - 8 - len(author_info)),
        \   revision,
        \ )
        \])
  return formatted
endfunction " }}}

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
  let blameobj = s:B.parse(result.stdout, { 'fail_silently': !g:gita#debug })
  let chunks = s:create_chunks(blameobj)
  let NAVI = []
  let VIEW = []
  let HORI = []
  for chunk in chunks
    let formatted_chunk = s:format_chunk(chunk, 49, len(chunk.contents) > 2)
    for i in range(max([2, len(chunk.contents)]))
      call add(NAVI, get(formatted_chunk, i, ''))
      call add(VIEW, get(chunk.contents, i, ''))
    endfor
    " Add an empty line for sign
    call add(NAVI, '')
    call add(VIEW, '')
    call add(HORI, len(NAVI))
  endfor
  let NAVI = NAVI[:-2]
  let VIEW = VIEW[:-2]

  let NAVI_bufname = gita#utils#buffer#bufname(
        \ options.file,
        \ 'BLAME',
        \ 'NAVI',
        \ options.commit,
        \)
  let VIEW_bufname = gita#utils#buffer#bufname(
        \ options.file,
        \ 'BLAME',
        \ 'VIEWER',
        \ options.commit,
        \)
  let bufnums = gita#utils#buffer#open2(
        \ VIEW_bufname, NAVI_bufname, 'gita_blame', {
        \   'opener': get(options, 'opener', 'tabedit'),
        \   'opener2': get(options, 'opener2', 'topleft 50 vsplit'),
        \   'range': get(options, 'range', 'all'),
        \})
  let VIEW_bufnum = bufnums.bufnum1
  let NAVI_bufnum = bufnums.bufnum2

  " VIEW
  execute printf('%swincmd w', bufwinnr(VIEW_bufnum))
  call gita#utils#buffer#update(VIEW)
  silent execute printf("setlocal filetype=%s", &l:filetype)
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setlocal nomodifiable readonly
  setlocal scrollbind cursorbind
  setlocal scrollopt=ver
  setlocal nowrap
  setlocal nofoldenable
  setlocal foldcolumn=0
  setlocal textwidth=0
  setlocal colorcolumn=0
  let b:_gita_original_filename = options.file
  execute printf('sign unplace * buffer=%d', VIEW_bufnum)
  for linenum in HORI
    "execute printf('syntax match GitaHorizontal /\%%%sl.*/', linenum)
    execute printf(
          \ 'sign place %d line=%d name=GitaHorizontalSign buffer=%d',
          \ linenum, linenum, VIEW_bufnum,
          \)
  endfor

  " NAVI
  execute printf('%swincmd w', bufwinnr(NAVI_bufnum))
  call gita#utils#buffer#update(NAVI)
  silent execute printf("setlocal filetype=%s", s:const.filetype)
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setlocal nomodifiable readonly
  setlocal scrollbind cursorbind
  setlocal scrollopt=ver
  setlocal nowrap
  setlocal nofoldenable
  setlocal nolist
  setlocal nonumber
  setlocal foldcolumn=0
  let b:_gita_original_filename = options.file
  execute printf('sign unplace * buffer=%d', NAVI_bufnum)
  for linenum in HORI
    execute printf(
          \ 'sign place %d line=%d name=GitaHorizontalSign buffer=%s',
          \ linenum, linenum, NAVI_bufnum,
          \)
  endfor
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
function! gita#features#blame#define_highlights() abort " {{{
  highlight link GitaHorizontal Comment
  highlight link GitaSummary    Title
  highlight link GitaMetaInfo   Comment
  highlight link GitaAuthor     Identifier
  highlight link GitaTimeDelta  Comment
  highlight link GitaRevision   String
  highlight      GitaHorizontal gui=underline guifg=#363636
endfunction " }}}
function! gita#features#blame#define_syntax() abort " {{{
  syntax match GitaSummary   /.*/
  syntax match GitaMetaInfo  /\v^.*\sauthored\s.*$/ contains=GitaAuthor,GitaTimeDelta,GitaRevision
  syntax match GitaAuthor    /\v^.*\ze\sauthored/ contained
  syntax match GitaTimeDelta /\vauthored\s\zs.*\ze\s+[0-9a-fA-F]{8}$/ contained
  syntax match GitaRevision  /\v[0-9a-fA-F]{8}$/ contained
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
