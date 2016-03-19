let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:String = s:V.import('Data.String')
let s:Path = s:V.import('System.Filepath')
let s:DateTime = s:V.import('DateTime')
let s:MemoryCache = s:V.import('System.Cache.Memory')
let s:Guard = s:V.import('Vim.Guard')
let s:Python = s:V.import('Vim.Python')
let s:Git = s:V.import('Git')
let s:GitParser = s:V.import('Git.Parser')
let s:ProgressBar = s:V.import('ProgressBar')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:execute_command(git, commit, filename) abort
  let args = [
        \ 'blame',
        \ g:gita#command#blame#use_porcelain_instead ? '--porcelain' : '--incremental',
        \ a:commit,
        \ '--',
        \ s:Path.unixpath(s:Git.get_relative_path(a:git, a:filename)),
        \]
  return gita#execute(a:git, args, {
        \ 'quiet': 1,
        \})
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita blame',
          \ 'description': 'Show what revision and author last modified each line of a file (UI only)',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ 'commit', [
          \   'A commit which you want to blame.',
          \   'If nothing is specified, it show a blame of HEAD.',
          \   'If <commit> is specified, it show a blame of the named <commit>.',
          \ ], {
          \   'complete': function('gita#complete#commit'),
          \ })

    call s:parser.add_argument(
          \ 'filename', [
          \   'A filename which you want to blame.',
          \   'If nothing is specified, the current buffer will be used.',
          \ ], {
          \   'complete': function('gita#complete#filename'),
          \ })
  endif
  return s:parser
endfunction

function! s:get_blameobj(content, commit, filename) abort
  let progressbar = s:ProgressBar.new(
        \ len(a:content), {
        \   'barwidth': 80,
        \   'statusline': 0,
        \})
  try
    let blameobj = s:GitParser.parse_blame(a:content, {
          \ 'progressbar': progressbar,
          \ 'python': g:gita#command#blame#use_python,
          \})
    if !g:gita#command#blame#use_porcelain_instead
      if empty(a:commit)
        let blameobj.file_content = readfile(a:filename)
      else
        let blameobj.file_content = gita#command#show#call({
              \ 'quiet': 1,
              \ 'commit': a:commit,
              \ 'filename': a:filename,
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
        \   'statusline': 0,
        \})
  try
    return s:format_blameobj(a:blameobj, a:width, progressbar)
  finally
    call progressbar.exit()
  endtry
endfunction


function! gita#command#blame#call(...) abort
  let options = extend({
        \ 'commit': '',
        \ 'filename': '',
        \}, get(a:000, 0, {}))
  let git = gita#core#get_or_fail()
  let commit = gita#variable#get_valid_range(git, options.commit, {
        \ '_allow_empty': 1,
        \})
  let filename = gita#variable#get_valid_filename(git, options.filename)
  let guard = s:Guard.store('&l:statusline')
  try
    setlocal statusline=Retriving\ blame\ content\ [1/3]\ ...
    redrawstatus
    let content = s:execute_command(git, commit, filename)
    setlocal statusline=Parsing\ blame\ content\ [2/3]\ ...
    redrawstatus
    let blameobj = s:get_blameobj(content, commit, filename)
    setlocal statusline=Formatting\ blame\ content\ [3/3]\ ...
    redrawstatus
    let blamemeta = s:get_blamemeta(
          \ blameobj,
          \ g:gita#command#blame#navigator_width
          \)
    return blamemeta
  finally
    call guard.restore()
  endtry
endfunction

function! gita#command#blame#get_or_call(...) abort
  let options = extend({
        \ 'commit': '',
        \ 'filename': '',
        \}, get(a:000, 0, {}))
  let git = gita#core#get_or_fail()
  let options.commit = gita#variable#get_valid_range(git, options.commit, {
        \ '_allow_empty': 1,
        \})
  let options.filename = gita#variable#get_valid_filename(git, options.filename)

  let bufname_view = gita#command#ui#blame_view#bufname(options)
  if bufexists(bufname_view) && !empty(getbufvar(bufname_view, '_gita_blame_cache'))
    return {
          \ 'commit': options.commit,
          \ 'filename': options.filename,
          \ 'blamemeta': getbufvar(bufname_view, '_gita_blame_cache'),
          \}
  endif

  let bufname_navi = gita#command#ui#blame_navi#bufname(options)
  if bufexists(bufname_navi) && !empty(getbufvar(bufname_navi, '_gita_blame_cache'))
    return {
          \ 'commit': options.commit,
          \ 'filename': options.filename,
          \ 'blamemeta': getbufvar(bufname_navi, '_gita_blame_cache'),
          \}
  endif

  let blamemeta = gita#command#blame#call(options)
  if bufexists(bufname_view)
    call setbufvar(bufname_view, '_gita_blame_cache', blamemeta)
  endif
  if bufexists(bufname_navi)
    call setbufvar(bufname_navi, '_gita_blame_cache', blamemeta)
  endif

  return {
        \ 'commit': options.commit,
        \ 'filename': options.filename,
        \ 'blamemeta': blamemeta,
        \}
endfunction

function! gita#command#blame#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#blame#default_options),
        \ options,
        \)
  call gita#option#assign_commit(options)
  call gita#option#assign_filename(options)
  call gita#option#assign_selection(options)
  call gita#command#ui#blame#open(options)
endfunction

function! gita#command#blame#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction


" Utilities ------------------------------------------------------------------

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


call gita#util#define_variables('command#blame', {
      \ 'default_options': {},
      \ 'use_porcelain_instead': 0,
      \ 'use_python': s:Python.is_enabled(),
      \ 'navigator_width': 50,
      \})
