let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:String = s:V.import('Data.String')
let s:DateTime = s:V.import('DateTime')
let s:MemoryCache = s:V.import('System.Cache.Memory')
let s:ProgressBar = s:V.import('ProgressBar')

function! s:get_chunkinfo_cache() abort
  if !exists('s:_chunkinfo_cache')
    let s:_chunkinfo_cache = s:MemoryCache.new()
  endif
  return s:_chunkinfo_cache
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
  return chunk.linenum.final + get(chunk.linenum, 'nlines', 1)
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
      let linesummary = s:String.truncate(a:chunk.summary, a:width)
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
  let cache = s:get_chunkinfo_cache()
  let linenum_width  = len(s:get_max_linenum(chunks))
  let linenum_spacer = repeat(' ', linenum_width)
  let linenum_pseudo = 1
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
    let height = max([2, n_contents])
    let formatted_chunk = s:format_chunk(
          \ chunk, width, height-1, cache, now, whitespaces
          \)
    for cursor in range(height)
      if cursor < n_contents
        call add(linerefs, linenum_pseudo)
      endif
      let linenum = cursor >= n_contents ? '' : chunk.linenum.final + cursor
      call add(navi_content,
              \ linenum_spacer[len(linenum):] . linenum . ' ' . get(formatted_chunk, cursor, '')
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
          \   'original': chunk.linenum.original + (height - 1),
          \   'final': chunk.linenum.final + (height - 1),
          \ },
          \})
    call add(separators, linenum_pseudo)
    let linenum_pseudo += 1
    if !empty(a:progressbar)
      call a:progressbar.update()
    endif
  endfor
  let offset = -2
  let blame = {
        \ 'chunks':       chunks,
        \ 'lineinfos':    lineinfos[:offset],
        \ 'linerefs':     linerefs,
        \ 'separators':   empty(separators) ? [] : separators[:offset],
        \ 'navi_content': navi_content[:offset],
        \ 'view_content': view_content[:offset],
        \ 'linenum_width': linenum_width,
        \}
  return blame
endfunction

function! gita#command#ui#blame#format(blameobj, width) abort
  let progressbar = s:ProgressBar.new(
        \ len(a:blameobj.chunks), {
        \   'barwidth': 80,
        \   'statusline': 1,
        \   'prefix': 'Constructing interface: ',
        \})
  try
    return s:format_blameobj(a:blameobj, a:width, progressbar)
  finally
    call progressbar.exit()
  endtry
endfunction

highlight default link GitaPseudoSeparator GitaPseudoSeparatorDefault
highlight GitaPseudoSeparatorDefault term=underline cterm=underline ctermfg=8 gui=underline guifg=#363636
if !exists('s:_sign_defined')
  sign define GitaPseudoSeparatorSign texthl=SignColumn linehl=GitaPseudoSeparator
  let s:_sign_defined = 1
endif

call gita#util#define_variables('command#ui#blame', {
      \ 'default_opener': 'tabnew',
      \})
