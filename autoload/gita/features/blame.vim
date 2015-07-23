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
          \ '--': [filename],
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
        \ '--': [filename],
        \ 'commit': revision,
        \})
  call setpos('.', linenum)
endfunction " }}}

function! s:ensure_file_option(options) abort " {{{
  if empty(get(a:options, '--', []))
    let a:options['--'] = ['%']
  elseif len(get(a:options, '--', [])) > 1
    call gita#utils#prompt#warn(
          \ 'A single file required to be specified to blame.',
          \)
    return -1
  endif
  let a:options.file = gita#utils#ensure_abspath(
        \ gita#utils#expand(a:options['--'][0]),
        \)
  return 0
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
function! s:get_candidates(start, end) abort " {{{
  let linechunks = gita#meta#get('blame#linechunks', [])
  return linechunks[a:start : a:end]
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
  if options.reverse
    " blame linenum to original linenum
    let linechunks = gita#meta#get('blame#linechunks', [])
    if !empty(linechunks)
      let linechunk = get(linechunks, a:linenum - 1, a:linenum)
      let linenum = linechunk.linenum.final
    else
      let linenum = a:linenum
    endif
  else
    " original linenum to blame linenum
    let linenumref = gita#meta#get('blame#linenumref', [])
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
function! gita#features#blame#exec(...) abort " {{{
  let gita = gita#get()
  let options = deepcopy(get(a:000, 0, {}))
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  if !empty(get(options, '--', []))
    let options['--'] = gita#utils#ensure_pathlist(options['--'])
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
  let options.commit = get(options, 'commit', 'HEAD')
  if s:ensure_file_option(options)
    return
  endif
  if !empty(get(options, '--', []))
    let options['--'] = gita#utils#ensure_pathlist(options['--'])
  endif
  let abspath = get(options['--'], 0)
  let relpath = gita.git.get_relative_path(abspath)

  let options.porcelain = 1
  let result = gita#features#blame#exec(options, {
        \ 'echo': 'fail',
        \})
  if result.status != 0
    return
  endif
  let blameobj = s:B.parse(result.stdout, { 'fail_silently': !g:gita#debug })
  let chunks = s:create_chunks(blameobj)
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
    call add(NAVI, '')
    call add(VIEW, '')
    call add(HORI, len(NAVI))
    call add(linechunks, chunk)
    let linenum += 1
  endfor
  let NAVI = NAVI[:-2]
  let VIEW = VIEW[:-2]

  let NAVI_bufname = gita#utils#buffer#bufname(
        \ 'BLAME',
        \ options.commit[:7],
        \ 'NAVI',
        \ relpath,
        \)
  let VIEW_bufname = gita#utils#buffer#bufname(
        \ 'BLAME',
        \ options.commit[:7],
        \ relpath,
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
  call gita#meta#extend({
        \ 'filename': abspath,
        \ 'commit': options.commit,
        \ 'blame#blameobj': blameobj,
        \ 'blame#linechunks': linechunks,
        \ 'blame#linenumref': linenumref,
        \})

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
  call gita#meta#extend({
        \ 'filename': abspath,
        \ 'commit': options.commit,
        \ 'blame#blameobj': blameobj,
        \ 'blame#linechunks': linechunks,
        \ 'blame#linenumref': linenumref,
        \})

  call gita#action#extend_actions(s:actions)
  call gita#action#set_candidates(function('s:get_candidates'))
  nmap <buffer> <CR> :call gita#action#exec('jump_in')<CR>
  nmap <buffer> <BS> :call gita#action#exec('jump_out')<CR>
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
