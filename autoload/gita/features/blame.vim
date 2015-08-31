let s:save_cpo = &cpo
set cpo&vim

let s:L = gita#import('Data.List')
let s:D = gita#import('Data.Dict')
let s:S = gita#import('Data.String')
let s:P = gita#import('System.Filepath')
let s:B = gita#import('VCS.Git.BlameParser')
let s:A = gita#import('ArgumentParser')


let s:const = {}
let s:const.filetype = 'gita-blame-navi'

highlight GitaPseudoSeparatorDefault
      \ term=underline
      \ cterm=underline ctermfg=8
      \ gui=underline guifg=#363636
sign define GitaPseudoSeparatorSign
      \ texthl=SignColumn
      \ linehl=GitaPseudoSeparator


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
function! s:actions.blame(candidates, options) abort " {{{
  for candidate in a:candidates
    call gita#features#blame#show({
          \ 'commit':  get(candidate, 'commit'),
          \ 'file':    get(candidate, 'path'),
          \ 'line':    get(candidate, 'line'),
          \ 'column':  get(candidate, 'column'),
          \ 'range':   get(a:options, 'range'),
          \ 'opener':  get(a:options, 'opener'),
          \ 'opener2': get(a:options, 'opener2'),
          \})
  endfor
endfunction " }}}

function! s:format_chunk(chunk, ...) abort " {{{
  let options = extend({
        \ 'width': winwidth(0),
        \ 'wrap': 0,
        \}, get(a:000, 0, {}))
  if options.wrap
    let summary = map(
          \ s:S.wrap(a:chunk.summary, options.width - 1),
          \ 'substitute(v:val, ''\v%(^\s+|\s+$)'', "", "g")',
          \)
  else
    let summary = s:S.truncate_skipping(
          \ a:chunk.summary,
          \ options.width - 2,
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
        \   repeat(' ', options.width - 8 - len(author_info)),
        \   revision,
        \ )
        \])
  return formatted
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
      " add forward/backward links
      if !empty(chunks)
        let chunks[-1].next_chunk = chunk
        let chunk.previous_chunk = chunks[-1]
      endif
      " overwrite contents
      let chunk.contents = [lineinfo.contents]
      call add(chunks, chunk)
    else
      " extend contents of last chunk
      let chunk = chunks[-1]
      call add(chunk.contents, lineinfo.contents)
    endif
  endfor
  return chunks
endfunction " }}}
function! s:create_chunkobj(chunks) abort " {{{
  let linechunks = []
  let linenumref = []
  let NAVI = []
  let VIEW = []
  let HORI = []
  let pseudo_separators = []
  let linenum = 1
  for chunk in a:chunks
    let formatted_chunk = s:format_chunk(chunk, {
          \ 'width': 47,
          \ 'wrap': len(chunk.contents) > 2,
          \})
    for i in range(max([g:gita#features#blame#enable_pseudo_separator ? 2 : 1, len(chunk.contents)]))
      if i < chunk.nlines
        call add(linenumref, linenum)
      endif
      call add(NAVI, get(formatted_chunk, i, ''))
      call add(VIEW, get(chunk.contents, i, ''))
      call add(linechunks, extend(deepcopy(chunk), {
            \ 'linenum': {
            \   'original': linenum - (chunk.linenum.final - chunk.linenum.original),
            \   'final':    linenum,
            \ },
            \}),
            \)
      let linenum += 1
    endfor
    " Add a pseudo line to separate chunks
    if g:gita#features#blame#enable_pseudo_separator
      call add(NAVI, '')
      call add(VIEW, '')
      call add(linechunks, chunk)
      call add(pseudo_separators, len(NAVI))
      let linenum += 1
    endif
  endfor
  let chunkobj = {
        \ 'linechunks': linechunks,
        \ 'linenumref': linenumref,
        \}
  if g:gita#features#blame#enable_pseudo_separator
    let chunkobj.pseudo_separators = pseudo_separators[:-2]
    let chunkobj.contents = {
          \ 'NAVI': NAVI[:-2],
          \ 'VIEW': VIEW[:-2],
          \}
  else
    let chunkobj.pseudo_separators = []
    let chunkobj.contents = {
          \ 'NAVI': NAVI,
          \ 'VIEW': VIEW,
          \}
  endif
  return chunkobj
endfunction "}}}
function! s:get_blameobj() abort " {{{
  return gita#meta#get('blame#blameobj', {})
endfunction " }}}
function! s:get_chunkobj() abort " {{{
  return gita#meta#get('blame#chunkobj', {})
endfunction " }}}
function! s:get_linechunks() abort " {{{
  let chunkobj = s:get_chunkobj()
  return get(chunkobj, 'linechunks', [])
endfunction " }}}
function! s:get_linenumref() abort " {{{
  let chunkobj = s:get_chunkobj()
  return get(chunkobj, 'linenumref', [])
endfunction " }}}
function! s:get_linechunk(...) abort " {{{
  let linenum = get(a:000, 0, line('.'))
  let linechunks = s:get_linechunks()
  return get(linechunks, linenum - 1, {})
endfunction " }}}
function! s:get_next_chunk(...) abort " {{{
  let linechunk = call('s:get_linechunk': a:000)
  return get(linechunk, 'next_chunk', {})
endfunction " }}}
function! s:get_previous_chunk(...) abort " {{{
  let linechunk = call('s:get_linechunk': a:000)
  return get(linechunk, 'previous_chunk', {})
endfunction " }}}
function! s:get_actual_linenum(pseudo_linenum) abort " {{{
  let linechunk = s:get_linechunk(a:pseudo_linenum)
  return get(get(linechunk, 'linenum', {}), 'final', -1)
endfunction " }}}
function! s:get_pseudo_linenum(actual_linenum) abort " {{{
  let linenumref = s:get_linenumref()
  return get(linenumref, a:actual_linenum - 1, a:actual_linenum)
endfunction " }}}
function! s:get_candidates(start, end) abort " {{{
  let current_commit   = gita#meta#get('commit', '')
  let current_filename = gita#meta#get('filename', '')
  let linechunks = s:get_linechunks()
  let candidates = []
  for linechunk in linechunks[a:start : a:end]
    if linechunk.revision ==# current_commit
      let previous = get(linechunk, 'previous', '')
      if empty(previous)
        continue
      endif
      let [commit, filename] = split(previous)
      let line = linechunk.linenum.original
    else
      let commit   = get(linechunk, 'revision', current_commit)
      let filename = get(linechunk, 'filename', current_filename)
      let line = linechunk.linenum.final
    endif
    let candidate = gita#utils#status#virtual(filename)
    let candidate = extend(candidate, {
          \ 'commit': commit,
          \ 'line': line,
          \})
    call add(candidates, candidate)
  endfor
  return candidates
endfunction " }}}
function! s:display_pseudo_separators() abort " {{{
  let bufnum = bufnr('%')
  let chunkobj = s:get_chunkobj()
  " remove all signs defined in the buffer
  execute printf('sign unplace * buffer=%d', bufnum)
  " place all signs to indicate the chunks
  for linenum in chunkobj.pseudo_separators
    execute printf(
          \ 'sign place %d line=%d name=GitaPseudoSeparatorSign buffer=%s',
          \ linenum, linenum, bufnum,
          \)
  endfor
endfunction " }}}
function! s:view_ac_BufWinEnter() abort " {{{
  let abspath = gita#meta#get('filename')
  let commit = gita#meta#get('commit')
  let blameobj = s:get_blameobj()
  let chunkobj = s:get_chunkobj()
  try
    let saved_eventignore = &eventignore
    set eventignore=BufWinEnter
    keepjumps call gita#features#blame#navi_open(abspath, commit, blameobj, chunkobj)
    let chunkobj.bufnums.NAVI_bufnum = bufnr('%')
    keepjumps wincmd p
  finally
    let &eventignore = saved_eventignore
  endtry
  call gita#features#blame#goto(s:get_actual_linenum(line('.')))
endfunction " }}}
function! s:navi_ac_BufWinEnter() abort " {{{
  let abspath = gita#meta#get('filename')
  let commit = gita#meta#get('commit')
  let blameobj = s:get_blameobj()
  let chunkobj = s:get_chunkobj()
  try
    let saved_eventignore = &eventignore
    set eventignore=BufWinEnter
    keepjumps call gita#features#blame#view_open(abspath, commit, blameobj, chunkobj)
    let chunkobj.bufnums.VIEW_bufnum = bufnr('%')
    keepjumps wincmd p
  finally
    let &eventignore = saved_eventignore
  endtry
  call gita#features#blame#goto(s:get_actual_linenum(line('.')))
endfunction " }}}

function! gita#features#blame#exec(...) abort " {{{
  let gita = gita#get()
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  let options = deepcopy(get(a:000, 0, {}))
  let config  = get(a:000, 1, {})

  " validate option
  if g:gita#develop
    call gita#utils#validate#require(options, 'file', 'options')
    call gita#utils#validate#empty(options.file, 'options.file')

    call gita#utils#validate#require(options, 'commit', 'options')
    call gita#utils#validate#empty(options.commit, 'options.commit')
    call gita#utils#validate#pattern(options.commit, '\v^[^ ]+', 'options.commit')
  endif

  if has_key(options, 'file')
    let options['--'] = [
          \ gita#utils#ensure_unixpath(gita#utils#expand(options.file))
          \]
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
function! gita#features#blame#exec_cached(...) abort " {{{
  let gita = gita#get()
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  let cache_name = s:P.join('blame', string(s:D.pick(options, [
        \ 'file',
        \ 'commit',
        \ 'porcelain',
        \])))
  let cached_status = gita.git.is_updated('index', 'blame') || get(config, 'force_update', 0)
        \ ? {}
        \ : gita.git.cache.repository.get(cache_name, {})
  if !empty(cached_status)
    return cached_status
  endif
  let result = gita#features#blame#exec(options, config)
  if result.status != get(config, 'success_status', 0)
    return result
  endif
  call gita.git.cache.repository.set(cache_name, result)
  return result
endfunction " }}}
function! gita#features#blame#show(...) abort " {{{
  let gita = gita#get()
  let options = get(a:000, 0, {})
  let options.file   = get(options, 'file', '%')
  let options.commit = get(options, 'commit', 'HEAD')
  let options.porcelain = 1
  let result = gita#features#blame#exec_cached(options, {
        \ 'echo': 'fail',
        \})
  if result.status != 0
    return
  endif
  let blameobj = s:B.parse(result.stdout, { 'fail_silently': !g:gita#debug })
  let chunkobj = s:create_chunkobj(s:create_chunks(blameobj))
  let abspath = gita#utils#ensure_abspath(gita#utils#expand(options.file))
  let commit  = options.commit
  try
    let saved_eventignore = &eventignore
    set eventignore=BufWinEnter
    call gita#features#blame#view_open(
          \ abspath, commit, blameobj, chunkobj, extend(deepcopy(options), {
          \  'range':  get(options, 'range'),
          \  'opener': get(options, 'opener'),
          \ }),
          \)
    let VIEW_bufnum = bufnr('%')
    call gita#features#blame#navi_open(
          \ abspath, commit, blameobj, chunkobj, extend(deepcopy(options), {
          \  'range':  get(options, 'range'),
          \  'opener': get(options, 'opener2'),
          \ }),
          \)
    let NAVI_bufnum = bufnr('%')
  finally
    let &eventignore = saved_eventignore
  endtry
  let chunkobj.bufnums = {
        \ 'VIEW': VIEW_bufnum,
        \ 'NAVI': NAVI_bufnum,
        \}
  keepjumps wincmd p
  call gita#features#blame#goto(
        \ get(options, 'line', s:get_actual_linenum(line('.')))
        \)
endfunction " }}}
function! gita#features#blame#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let options = extend(deepcopy(g:gita#features#blame#default_options), {
          \ 'line': has_key(options, 'file') ? 0 : line('.'),
          \ 'column': has_key(options, 'file') ? 0 : col('.'),
          \})
    call gita#features#blame#show(options)
  endif
endfunction " }}}
function! gita#features#blame#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}
function! gita#features#blame#goto(linenum, ...) abort " {{{
  let chunkobj = s:get_chunkobj()
  let bufnum = bufnr('%')
  call setbufvar(chunkobj.bufnums.VIEW, '&scrollbind', 0)
  call setbufvar(chunkobj.bufnums.NAVI, '&scrollbind', 0)
  " NAVI
  execute printf('%dwincmd w', bufwinnr(chunkobj.bufnums.NAVI))
  let pseudo_linenum = s:get_pseudo_linenum(a:linenum)
  call setpos('.', [0, pseudo_linenum, col('.'), 0])
  " VIEW
  execute printf('%dwincmd w', bufwinnr(chunkobj.bufnums.VIEW))
  let col = get(a:000, 0, col('.'))
  let off = get(a:000, 1, 0)
  call setpos('.', [0, pseudo_linenum, col, off])
  call setbufvar(chunkobj.bufnums.VIEW, '&scrollbind', 1)
  call setbufvar(chunkobj.bufnums.NAVI, '&scrollbind', 1)
  execute printf('%dwincmd w', bufwinnr(bufnum))
  return pseudo_linenum
endfunction " }}}

function! gita#features#blame#view_open(abspath, commit, blameobj, chunkobj, ...) abort " {{{
  let options = get(a:000, 0, {})
  let gita    = gita#get(a:abspath)
  let relpath = gita.git.get_relative_path(a:abspath)
  let bufname = gita#utils#buffer#bufname(
        \ 'BLAME',
        \ a:commit,
        \ relpath,
        \)
  silent keepjumps call gita#utils#buffer#open(bufname, {
        \ 'group': 'blame_view',
        \ 'range':  gita#utils#eget(options, 'range', 'tabpage'),
        \ 'opener': gita#utils#eget(options, 'opener', 'tabedit'),
        \})
  setlocal buftype=nofile noswapfile
  setlocal nomodifiable
  setlocal nowrap nofoldenable
  call gita#meta#extend({
        \ 'commit': a:commit,
        \ 'filename': a:abspath,
        \ 'blame#blameobj': a:blameobj,
        \ 'blame#chunkobj': a:chunkobj,
        \})
  call gita#action#extend_actions(s:actions)
  call gita#action#set_candidates(function('s:get_candidates'))
  call gita#utils#buffer#update(a:chunkobj.contents.VIEW)
  call s:display_pseudo_separators()
  call gita#features#blame#view_define_mappings()
  if g:gita#features#blame#enable_default_mappings || g:gita#features#blame#view_enable_default_mappings
    call gita#features#blame#view_define_default_mappings()
  endif
  augroup vim-gita-blame-view-au
    autocmd! * <buffer>
    autocmd BufWinEnter <buffer> call s:view_ac_BufWinEnter()
  augroup END
  execute printf("setlocal filetype=%s", &l:filetype)
endfunction " }}}
function! gita#features#blame#view_define_mappings() abort " {{{
  call gita#monitor#define_mappings()
  unmap <buffer> <Plug>(gita-action-help-s)

  nnoremap <buffer><silent> <Plug>(gita-blame-blame)
        \ :<C-u>call gita#action#exec('blame')<CR>
endfunction " }}}
function! gita#features#blame#view_define_default_mappings() abort " {{{
  call gita#monitor#define_default_mappings()

  unmap <buffer> ?s
  nmap <buffer> <CR> <Plug>(gita-blame-blame)
endfunction " }}}

function! gita#features#blame#navi_open(abspath, commit, blameobj, chunkobj, ...) abort " {{{
  let options = get(a:000, 0, {})
  let gita    = gita#get(a:abspath)
  let relpath = gita.git.get_relative_path(a:abspath)
  let bufname = gita#utils#buffer#bufname(
        \ 'BLAME',
        \ a:commit,
        \ 'NAVI',
        \ relpath,
        \)
  silent keepjumps call gita#utils#buffer#open(bufname, {
        \ 'group': 'blame_navi',
        \ 'range':  gita#utils#eget(options, 'range', 'tabpage'),
        \ 'opener': gita#utils#eget(options, 'opener', 'topleft 50 vsplit'),
        \})
  setlocal buftype=nofile noswapfile
  setlocal nomodifiable
  setlocal nowrap nofoldenable nolist nonumber foldcolumn=0
  call gita#meta#extend({
        \ 'commit': a:commit,
        \ 'filename': a:abspath,
        \ 'blame#blameobj': a:blameobj,
        \ 'blame#chunkobj': a:chunkobj,
        \})
  call gita#action#extend_actions(s:actions)
  call gita#action#set_candidates(function('s:get_candidates'))
  call gita#utils#buffer#update(a:chunkobj.contents.NAVI)
  call s:display_pseudo_separators()
  call gita#features#blame#view_define_mappings()
  if g:gita#features#blame#enable_default_mappings || g:gita#features#blame#navi_enable_default_mappings
    call gita#features#blame#view_define_default_mappings()
  endif
  augroup vim-gita-blame-navi-au
    autocmd! * <buffer>
    autocmd BufWinEnter <buffer> call s:navi_ac_BufWinEnter()
  augroup END
  execute printf("setlocal filetype=%s", s:const.filetype)
endfunction " }}}
function! gita#features#blame#navi_define_mappings() abort " {{{
  call gita#monitor#define_mappings()
  unmap <buffer> <Plug>(gita-action-help-s)

  nnoremap <buffer><silent> <Plug>(gita-blame-blame)
        \ :<C-u>call gita#action#exec('blame')<CR>
endfunction " }}}
function! gita#features#blame#navi_define_default_mappings() abort " {{{
  call gita#monitor#define_default_mappings()

  unmap <buffer> ?s
  nmap <buffer> <CR> <Plug>(gita-blame-blame)
endfunction " }}}
function! gita#features#blame#navi_define_highlights() abort " {{{
  highlight default link GitaHorizontal Comment
  highlight default link GitaSummary    Title
  highlight default link GitaMetaInfo   Comment
  highlight default link GitaAuthor     Identifier
  highlight default link GitaTimeDelta  Comment
  highlight default link GitaRevision   String
  highlight default link GitaPseudoSeparator GitaPseudoSeparatorDefault
endfunction " }}}
function! gita#features#blame#navi_define_syntax() abort " {{{
  syntax match GitaSummary   /.*/
  syntax match GitaMetaInfo  /\v^.*\sauthored\s.*$/ contains=GitaAuthor,GitaTimeDelta,GitaRevision
  syntax match GitaAuthor    /\v^.*\ze\sauthored/ contained
  syntax match GitaTimeDelta /\vauthored\s\zs.*\ze\s+[0-9a-fA-F]{8}$/ contained
  syntax match GitaRevision  /\v[0-9a-fA-F]{8}$/ contained
endfunction " }}}

function! gita#features#blame#_get_linechunk(...) abort " {{{
  return call('s:get_linechunk', a:000)
endfunction " }}}
function! gita#features#blame#_get_actual_linenum(...) abort " {{{
  return call('s:get_actual_linenum', a:000)
endfunction " }}}
function! gita#features#blame#_get_pseudo_linenum(...) abort " {{{
  return call('s:get_pseudo_linenum', a:000)
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
