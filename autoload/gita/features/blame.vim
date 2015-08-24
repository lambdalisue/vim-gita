let s:save_cpo = &cpo
set cpo&vim

let s:L = gita#import('Data.List')
let s:D = gita#import('Data.Dict')
let s:S = gita#import('Data.String')
let s:B = gita#import('VCS.Git.BlameParser')
let s:A = gita#import('ArgumentParser')


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

let s:actions = {}
function! s:actions.jump_in(candidates, options) abort " {{{
  let history = s:get_history()
  let current_commit = gita#meta#get('commit')
  let current_filename = gita#meta#get('filename')
  for candidate in a:candidates
    if candidate.revision ==# current_commit
      let previous = get(candidate, 'previous', '')
      if empty(previous)
        call gita#utils#prompt#warn(
              \ 'This is a boundary commit',
              \)
        continue
      endif
      let [revision, filename] = split(previous)
    else
      let revision = candidate.revision
      let filename = candidate.filename
    endif
    call s:L.push(history, [
          \ current_commit,
          \ current_filename,
          \ gita#compat#getcurpos(),
          \])
    call gita#features#blame#show({
          \ 'file': filename,
          \ 'commit': revision,
          \})
    call gita#features#blame#goto(candidate.linenum.original)
  endfor
endfunction " }}}
function! s:actions.jump_out(candidates, options) abort " {{{
  let history = s:get_history()
  if empty(history)
    call gita#utils#prompt#warn(
          \ 'This is a boundary commit',
          \)
    return
  endif
  let [revision, filename, linenum] = s:L.pop(history)
  call gita#features#blame#show({
        \ 'file': filename,
        \ 'commit': revision,
        \})
  call setpos('.', linenum)
endfunction " }}}

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
      " add forward/backward link
      if !empty(chunks)
        let chunks[-1].next = chunk
        let chunk.previous = chunks[-1]
      endif
      " overwrite contents
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
function! s:extend_blameobj(blameobj) abort " {{{
  let chunks = s:create_chunks(a:blameobj)
  let linechunks = []
  let linenumref = []
  let NAVI = []
  let VIEW = []
  let HORI = []
  let linenum = 1
  for chunk in chunks
    let formatted_chunk = s:format_chunk(chunk, 47, len(chunk.contents) > 2)
    for i in range(max([2, len(chunk.contents)]))
      if i < chunk.nlines
        call add(linenumref, linenum)
      endif
      call add(NAVI, get(formatted_chunk, i, ''))
      call add(VIEW, get(chunk.contents, i, ''))
      call add(linechunks, chunk)
      let linenum += 1
    endfor
    " Add an empty line for sign
    if g:gita#features#blame#enable_horizontal_signs
      call add(NAVI, '')
      call add(VIEW, '')
      call add(HORI, len(NAVI))
      call add(linechunks, chunk)
      let linenum += 1
    endif
  endfor
  let blameobj = copy(a:blameobj)
  let blameobj.linechunks = linechunks
  let blameobj.linenumref = linenumref
  if g:gita#features#blame#enable_horizontal_signs
    let blameobj.horizontal_signs = HORI[:-2]
    let blameobj.contents = {
          \ 'NAVI': NAVI[:-2],
          \ 'VIEW': VIEW[:-2],
          \}
  else
    let blameobj.contents = {
          \ 'NAVI': NAVI,
          \ 'VIEW': VIEW,
          \}
  endif
  return blameobj
endfunction "}}}
function! s:get_candidates(start, end) abort " {{{
  let blameobj = gita#meta#get('blame#blameobj', [])
  return blameobj.linechunks[a:start : a:end]
endfunction " }}}
function! s:get_history() abort " {{{
  let w:_gita_blame_history = get(w:, '_gita_blame_history', [])
  return w:_gita_blame_history
endfunction " }}}

function! gita#features#blame#goto(linenum, ...) abort " {{{
  let options = extend({
        \ 'reverse': 0,
        \ 'move': 1,
        \}, get(a:000, 0, {}))
  let blameobj = gita#meta#get('blame#blameobj', {})
  if options.reverse
    " blame linenum to original linenum
    let linechunks = get(blameobj, 'linechunks', [])
    if !empty(linechunks)
      let linechunk = get(linechunks, a:linenum - 1, a:linenum)
      let linenum = linechunk.linenum.final
    else
      let linenum = a:linenum
    endif
  else
    " original linenum to blame linenum
    let linenumref = get(blameobj, 'linenumref', [])
    if !empty(linenumref)
      let linenum = get(linenumref, a:linenum - 1, a:linenum)
    else
      let linenum = a:linenum
    endif
  endif
  if options.move
    call setpos('.', [0, linenum, 0, 0])
  endif
  return linenum
endfunction " }}}
function! gita#features#blame#get_actual_linenum(linenum) abort " {{{
  let blameobj = gita#meta#get('blame#blameobj', {})
  let linechunks = get(blameobj, 'linechunks', [])
  let chunk = get(linechunks, a:linenum - 1, {})
  return get(get(chunk, 'linenum', {}), 'final', -1)
endfunction " }}}
function! gita#features#blame#get_pseudo_linenum(linenum) abort " {{{
  let blameobj = gita#meta#get('blame#blameobj', {})
  let linenumref = get(blameobj, 'linenumref', [])
  return get(linenumref, a:linenum - 1, -1)
endfunction " }}}
function! gita#features#blame#get_next_chunk(linenum) abort " {{{
  let blameobj = gita#meta#get('blame#blameobj', {})
  let linechunks = get(blameobj, 'linechunks', [])
  let chunk = get(linechunks, a:linenum - 1, {})
  return get(chunk, 'next', {})
endfunction " }}}
function! gita#features#blame#get_previous_chunk(linenum) abort " {{{
  let blameobj = gita#meta#get('blame#blameobj', {})
  let linechunks = get(blameobj, 'linechunks', [])
  let chunk = get(linechunks, a:linenum - 1, {})
  return get(chunk, 'previous', {})
endfunction " }}}
function! gita#features#blame#exec(...) abort " {{{
  let gita = gita#get()
  let options = deepcopy(get(a:000, 0, {}))
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  if has_key(options, 'file')
    let options['--'] = [gita#utils#ensure_unixpath(options.file)]
  endif
  if has_key(options, 'commit')
    let options.commit = substitute(options.commit, 'INDEX', '', 'g')
  endif
  let options = s:D.pick(options, [
        \ '--',
        \ 'porcelain',
        \ 'commit',
        \])
  return gita.operations.blame(options, config)
endfunction " }}}
function! gita#features#blame#show(...) abort " {{{
  let gita = gita#get()
  let options = get(a:000, 0, {})
  let options.file = get(options, 'file', '%')
  let options.commit = get(options, 'commit', 'HEAD')
  let options.porcelain = 1
  let result = gita#features#blame#exec(options, {
        \ 'echo': 'fail',
        \})
  if result.status != 0
    return
  endif
  let blameobj = s:extend_blameobj(
        \ s:B.parse(result.stdout, { 'fail_silently': !g:gita#debug }),
        \)
  let abspath = gita#utils#ensure_abspath(gita#utils#expand(options.file))
  let relpath = gita.git.get_relative_path(abspath)

  " VIEW
  let VIEW_bufname = gita#utils#buffer#bufname(
        \ 'BLAME',
        \ options.commit[:7],
        \ relpath,
        \)
  silent let result = gita#utils#buffer#open(VIEW_bufname, {
        \ 'group': 'blame_view',
        \ 'range': get(options, 'range', 'tabpage'),
        \ 'opener': get(options, 'opener', 'tabedit'),
        \})
  let VIEW_bufnum = result.bufnum
  setlocal buftype=nofile noswapfile
  setlocal nomodifiable readonly
  setlocal scrollbind cursorbind
  setlocal scrollopt=ver
  setlocal nowrap
  setlocal nofoldenable
  setlocal foldcolumn=0
  setlocal textwidth=0
  setlocal colorcolumn=0
  call gita#meta#extend({
        \ 'filename': abspath,
        \ 'commit': options.commit,
        \ 'blame#blameobj': blameobj,
        \})
  call gita#utils#buffer#update(blameobj.contents.VIEW)
  execute printf('sign unplace * buffer=%d', VIEW_bufnum)
  for linenum in blameobj.horizontal_signs
    execute printf(
          \ 'sign place %d line=%d name=GitaHorizontalSign buffer=%d',
          \ linenum, linenum, VIEW_bufnum,
          \)
  endfor
  execute printf("setlocal filetype=%s", &l:filetype)

  " NAVI
  let NAVI_bufname = gita#utils#buffer#bufname(
        \ 'BLAME',
        \ options.commit[:7],
        \ 'NAVI',
        \ relpath,
        \)
  silent let result = gita#utils#buffer#open(NAVI_bufname, {
        \ 'group': 'blame_navi',
        \ 'range': get(options, 'range', 'tabpage'),
        \ 'opener': get(options, 'opener2', 'topleft 50 vsplit'),
        \})
  let NAVI_bufnum = result.bufnum
  setlocal buftype=nofile noswapfile
  setlocal nomodifiable readonly
  setlocal scrollbind cursorbind
  setlocal scrollopt=ver
  setlocal nowrap
  setlocal nofoldenable
  setlocal nolist
  setlocal nonumber
  setlocal foldcolumn=0
  nnoremap <buffer><silent> <Plug>(gita-blame-jump-in)  :<C-u>call gita#action#exec('jump_in')<CR>
  nnoremap <buffer><silent> <Plug>(gita-blame-jump-out) :<C-u>call gita#action#exec('jump_out')<CR>
  nmap <buffer> <CR> <Plug>(gita-blame-jump-in)
  nmap <buffer> <BS> <Plug>(gita-blame-jump-out)
  call gita#meta#extend({
        \ 'filename': abspath,
        \ 'commit': options.commit,
        \ 'blame#blameobj': blameobj,
        \})
  call gita#action#extend_actions(s:actions)
  call gita#action#set_candidates(function('s:get_candidates'))
  call gita#utils#buffer#update(blameobj.contents.NAVI)
  execute printf('sign unplace * buffer=%d', NAVI_bufnum)
  for linenum in blameobj.horizontal_signs
    execute printf(
          \ 'sign place %d line=%d name=GitaHorizontalSign buffer=%s',
          \ linenum, linenum, NAVI_bufnum,
          \)
  endfor
  execute printf("setlocal filetype=%s", s:const.filetype)
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
  highlight      GitaHorizontal term=underline
        \ cterm=underline ctermfg=8
        \ gui=underline guifg=#363636
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
