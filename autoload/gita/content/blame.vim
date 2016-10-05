let s:V = gita#vital()
let s:String = s:V.import('Data.String')
let s:DateTime = s:V.import('DateTime')
let s:Path = s:V.import('System.Filepath')
let s:MemoryCache = s:V.import('System.Cache.Memory')
let s:Guard = s:V.import('Vim.Guard')
let s:Python = s:V.import('Vim.Python')
let s:ProgressBar = s:V.import('ProgressBar')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitTerm = s:V.import('Git.Term')
let s:GitParser = s:V.import('Git.Parser')

function! s:args_from_options(git, options) abort
  let args = gita#process#args_from_options(a:options, {
        \ 'w': 1,
        \})
  let args = [
        \ 'blame',
        \ g:gita#content#blame#use_porcelain_instead
        \   ? '--porcelain'
        \   : '--incremental',
        \] + args + [
        \ gita#normalize#commit(a:git, get(a:options, 'commit', '')),
        \ '--',
        \ gita#normalize#relpath(a:git, a:options.filename),
        \]
  return filter(args, '!empty(v:val)')
endfunction

function! s:execute_command(options) abort
  let git = gita#core#get_or_fail()
  let guard = s:Guard.store(['&l:statusline'])
  try
    setlocal statusline=Retriving\ blame\ content\ [1/3]\ ...
    redrawstatus
    let args = s:args_from_options(git, a:options)
    let content = gita#process#execute(git, args, {
          \ 'quiet': 1,
          \ 'encode_output': 0,
          \}).content
    setlocal statusline=Parsing\ blame\ content\ [2/3]\ ...
    redrawstatus
    let blameobj = s:get_blameobj(
          \ content,
          \ a:options.commit,
          \ a:options.filename
          \)
    setlocal statusline=Formatting\ blame\ content\ [3/3]\ ...
    redrawstatus
    let blamemeta = s:get_blamemeta(
          \ blameobj,
          \ g:gita#content#blame#navigator_width
          \)
    return blamemeta
  finally
    call guard.restore()
  endtry
endfunction

function! s:get_blameobj(content, commit, filename) abort
  let progressbar = s:ProgressBar.new(
        \ len(a:content), {
        \   'barwidth': 80,
        \   'method': 'echo',
        \})
  try
    let blameobj = s:GitParser.parse_blame(a:content, {
          \ 'progressbar': progressbar,
          \ 'python': g:gita#content#blame#use_python,
          \})
    if !g:gita#content#blame#use_porcelain_instead
      if empty(a:commit)
        let blameobj.file_content = readfile(a:filename)
      else
        let git = gita#core#get_or_fail()
        let args = ['show', printf('%s:%s',
              \ gita#normalize#commit(git, a:commit),
              \ gita#normalize#relpath(git, a:filename),
              \)]
        let blameobj.file_content = gita#process#execute(git, args, {
              \ 'quiet': 1,
              \ 'encode_output': 0,
              \}).content
      endif
    endif
    return blameobj
  finally
    call progressbar.exit()
  endtry
endfunction

function! s:get_blamemeta(blameobj, width) abort
  let progressbar = s:ProgressBar.new(
        \ len(a:blameobj.chunks), {
        \   'barwidth': 80,
        \   'method': 'echo',
        \})
  try
    return s:format_blameobj(a:blameobj, a:width, progressbar)
  finally
    call progressbar.exit()
  endtry
endfunction

function! s:format_timestamp(timestamp, timezone, now) abort
  let datetime  = s:DateTime.from_unix_time(a:timestamp, a:timezone)
  let timedelta = datetime.delta(a:now)
  if timedelta.duration().months() < 3
    return timedelta.about()
  elseif datetime.year() == a:now.year()
    return 'on ' . datetime.strftime('%d %b')
  else
    return 'on ' . datetime.strftime('%d %b, %Y')
  endif
endfunction

function! s:get_max_linenum(chunks) abort
  let chunk = a:chunks[len(a:chunks) - 1]
  return chunk.linenum.final + get(chunk, 'nlines', 1)
endfunction

function! s:build_chunkinfo(chunk, width, now, whitespaces) abort
  let summary = s:String.wrap(a:chunk.summary, a:width)
  let revision = (get(a:chunk, 'boundary') ? '^' : ' ') . a:chunk.revision[:6]
  let author = a:chunk.author
  let timestr = s:format_timestamp(
        \ a:chunk.author_time,
        \ a:chunk.author_tz,
        \ a:now,
        \)
  if author =~# 'Not Committed Yet'
    let author_info = 'Not committed yet ' . timestr
  else
    let author_info = author . ' authored ' . timestr
  endif
  let epilogue = author_info . a:whitespaces[9+len(author_info):] . revision
  return { 'nlines': len(summary), 'summary': summary, 'epilogue': epilogue }
endfunction

function! s:format_chunk(chunk, width, height, cache, now, whitespaces) abort
  let chunkinfo = a:cache.get(a:chunk.revision, {})
  if empty(chunkinfo)
    let chunkinfo = s:build_chunkinfo(a:chunk, a:width, a:now, a:whitespaces)
    call a:cache.set(a:chunk.revision, chunkinfo)
  endif
  if a:height == 1
    if !has_key(chunkinfo, 'linesummary')
      " produce a linesummary only when it becomes necessary
      let linesummary = s:String.truncate(a:chunk.summary, a:width - 1)
      let chunkinfo.linesummary = substitute(linesummary, '\s\+$', '', '')
      call a:cache.set(a:chunk.revision, chunkinfo)
    endif
    return [chunkinfo.linesummary, chunkinfo.epilogue]
  else
    let summary = chunkinfo.nlines > a:height
          \ ? chunkinfo.summary[:(a:height-1)]
          \ : chunkinfo.summary
    return summary + [chunkinfo.epilogue]
  endif
endfunction

function! s:format_blameobj(blameobj, width, progressbar) abort
  let chunks    = a:blameobj.chunks
  let revisions = a:blameobj.revisions
  let now   = s:DateTime.now()
  let cache = s:MemoryCache.new()
  let linenum_width  = len(s:get_max_linenum(chunks))
  let linenum_spacer = repeat(' ', linenum_width)
  let linenum_pseudo = 1
  let height = winheight(0)
  let width = a:width - linenum_width - 2
  let whitespaces = repeat(' ', width)
  let navi_content = []
  let view_content = []
  let lineinfos = []
  let linerefs = []
  let separators = []
  for chunk in chunks
    call extend(chunk, revisions[chunk.revision])
    " NOTE:
    " edit/show/diff actions require 'path' attribute
    let chunk.path = chunk.filename
    let n_contents = get(chunk, 'nlines', 1)
    let chunk_height = max([2, n_contents])
    let formatted_chunk = s:format_chunk(
          \ chunk, width, chunk_height-1, cache, now, whitespaces
          \)
    for cursor in range(chunk_height)
      if cursor < n_contents
        call add(linerefs, linenum_pseudo)
      endif
      let linenum = cursor >= n_contents ? '' : chunk.linenum.final + cursor
      call add(navi_content,
              \ linenum_spacer[len(linenum):] . linenum . ' ' . get(
              \   formatted_chunk,
              \   float2nr(fmod(cursor, height)),
              \   ''
              \ )
              \)
      if empty(linenum)
        call add(view_content, '')
      elseif len(chunk.contents) == n_contents
        call add(view_content, chunk.contents[cursor])
      else
        call add(view_content, a:blameobj.file_content[linenum-1])
      endif
      call add(lineinfos, {
            \ 'chunkref': chunk.index,
            \ 'linenum': {
            \   'original': chunk.linenum.original + cursor,
            \   'final': chunk.linenum.final + cursor,
            \ },
            \})
      let linenum_pseudo += 1
    endfor
    " add pseudo separator line
    call add(navi_content, '')
    call add(view_content, '')
    call add(lineinfos, {
          \ 'chunkref': chunk.index,
          \ 'linenum': {
          \   'original': chunk.linenum.original + (chunk_height - 1),
          \   'final': chunk.linenum.final + (chunk_height - 1),
          \ },
          \})
    call add(separators, linenum_pseudo)
    let linenum_pseudo += 1
    call a:progressbar.update()
  endfor
  let offset = -2
  let blamemeta = {
        \ 'chunks':       chunks,
        \ 'lineinfos':    lineinfos[:offset],
        \ 'linerefs':     linerefs,
        \ 'separators':   len(separators) < 2 ? [] : separators[:offset],
        \ 'navi_content': navi_content[:offset],
        \ 'view_content': view_content[:offset],
        \ 'linenum_width': linenum_width,
        \}
  return blamemeta
endfunction

function! gita#content#blame#retrieve(options) abort
  let bufname_view = gita#content#blame_view#build_bufname(a:options)
  if bufexists(bufname_view) && !empty(getbufvar(bufname_view, '_gita_blame_cache'))
    return getbufvar(bufname_view, '_gita_blame_cache')
  endif

  let bufname_navi = gita#content#blame_navi#build_bufname(a:options)
  if bufexists(bufname_navi) && !empty(getbufvar(bufname_navi, '_gita_blame_cache'))
    return getbufvar(bufname_navi, '_gita_blame_cache')
  endif

  let blamemeta = s:execute_command(a:options)
  if bufexists(bufname_view)
    call setbufvar(bufname_view, '_gita_blame_cache', blamemeta)
  endif
  if bufexists(bufname_navi)
    call setbufvar(bufname_navi, '_gita_blame_cache', blamemeta)
  endif

  return blamemeta
endfunction

function! gita#content#blame#open(options) abort
  let options = extend({
        \ 'opener': 'tabedit',
        \ 'window': 'blame_navi',
        \ 'selection': [],
        \ 'navigator_width': g:gita#content#blame#navigator_width,
        \}, a:options)
  let bufname = gita#content#blame_navi#build_bufname(options)
  call gita#util#cascade#set('blame-navi', options)
  call gita#util#buffer#open(bufname, {
        \ 'opener': options.opener,
        \ 'window': options.window,
        \})
  setlocal scrollbind
  call gita#util#syncbind()
  call gita#content#blame#define_highlights()
  call gita#content#blame#select(
        \ gita#content#blame#retrieve(options),
        \ options.selection
        \)
endfunction

function! gita#content#blame#define_highlights() abort
  highlight GitaPseudoSeparatorDefault
        \ term=underline cterm=underline ctermfg=242 gui=underline guifg=#363636
  highlight default link GitaPseudoSeparator GitaPseudoSeparatorDefault
  sign define GitaPseudoSeparatorSign texthl=SignColumn linehl=GitaPseudoSeparator
  sign define GitaPseudoEmptySign
endfunction

function! gita#content#blame#select(blamemeta, selection) abort
  " pseudo -> actual
  let line_start = get(a:selection, 0, 1)
  let line_end = get(a:selection, 1, line_start)
  let actual_selection = [
        \ gita#content#blame#get_actual_linenum(a:blamemeta, line_start),
        \ gita#content#blame#get_actual_linenum(a:blamemeta, line_end),
        \]
  call gita#util#buffer#select(actual_selection)
endfunction

function! gita#content#blame#get_candidates(startline, endline) abort
  let blamemeta = gita#meta#get_for('^blame-', 'blamemeta', {
        \ 'lineinfos': {}
        \})
  let candidates = []
  for linenum in range(a:startline, a:endline)
    let lineinfo = get(blamemeta.lineinfos, linenum - 1, {})
    call add(candidates, empty(lineinfo)
          \ ? {}
          \ : blamemeta.chunks[lineinfo.chunkref]
          \)
  endfor
  return candidates
endfunction

function! gita#content#blame#get_pseudo_linenum(blamemeta, linenum) abort
  " actual -> pseudo
  let lineinfos = a:blamemeta.lineinfos
  if a:linenum > len(lineinfos)
    let lineinfo = lineinfos[-1]
  elseif a:linenum <= 0
    let lineinfo = lineinfos[0]
  else
    let lineinfo = lineinfos[a:linenum - 1]
  endif
  return lineinfo.linenum.final
endfunction

function! gita#content#blame#get_actual_linenum(blamemeta, linenum) abort
  " pseudo -> actual
  let linerefs = a:blamemeta.linerefs
  if a:linenum > len(linerefs)
    return linerefs[-1]
  elseif a:linenum <= 0
    return linerefs[0]
  else
    return linerefs[a:linenum-1]
  endif
endfunction

function! gita#content#blame#set_pseudo_separators(blamemeta) abort
  let bufnum = bufnr('%')
  execute printf('sign unplace * buffer=%d', bufnum)
  execute printf(
        \ 'sign place 1 line=1 name=GitaPseudoEmptySign buffer=%d',
        \ bufnum,
        \)
  for linenum in a:blamemeta.separators
    execute printf(
          \ 'sign place %d line=%d name=GitaPseudoSeparatorSign buffer=%d',
          \ linenum, linenum, bufnum,
          \)
  endfor
endfunction

call gita#define_variables('content#blame', {
      \ 'use_porcelain_instead': 0,
      \ 'use_python': s:Python.is_enabled(),
      \ 'navigator_width': 50,
      \})
