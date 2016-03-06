let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:DateTime = s:V.import('DateTime')
let s:String = s:V.import('Data.String')
let s:Path = s:V.import('System.Filepath')
let s:MemoryCache = s:V.import('System.Cache.Memory')
let s:Prompt = s:V.import('Vim.Prompt')
let s:Guard = s:V.import('Vim.Guard')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:Git = s:V.import('Git')
let s:GitParser = s:V.import('Git.Parser')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')
let s:ProgressBar = s:V.import('ProgressBar')

function! s:pick_available_options(options) abort
  let options = s:Dict.pick(a:options, [
        \ 'porcelain',
        \ 'incremental',
        \])
  return options
endfunction
function! s:format_content(content) abort
  let progressbar = s:ProgressBar.new(
        \ len(a:content), {
        \   'barwidth': 80,
        \   'statusline': 0,
        \   'prefix': 'Parsing blame content: ',
        \})
  try
    return s:GitParser.parse_blame(a:content, progressbar)
  finally
    call progressbar.exit()
  endtry
endfunction
function! s:get_blameobj(git, commit, filename, options) abort
  " NOTE:
  " Usually gita provide a way to get a raw content but formatting raw content
  " of blame is timeconsuming and the result requires to be cached so do not
  " return a raw content to reduce cache size
  let options = s:pick_available_options(a:options)
  if g:gita#command#blame#use_porcelain_instead
    let options['porcelain'] = 1
  else
    let options['incremental'] = 1
  endif
  let options['commit'] = a:commit
  let options['--'] = [
        \ s:Path.unixpath(s:Git.get_relative_path(a:git, a:filename)),
        \]
  redraw | echo 'Retrieving a blame content...'
  let result = gita#execute(a:git, 'blame', options)
  redraw | echo
  if result.status
    call s:GitProcess.throw(result.stdout)
  endif
  let blameobj = s:format_content(result.content)
  if !get(options, 'porcelain')
    if empty(a:commit)
      let blameobj.file_content = readfile(a:filename)
    else
      let blameobj.file_content = gita#command#show#call({
            \ 'commit': a:commit,
            \ 'filename': a:filename,
            \}).content
    endif
  endif
  return blameobj
endfunction
function! s:get_cached_blameobj(git, commit, filename, options) abort
  let cachename = join([
        \ a:commit, a:filename,
        \ g:gita#command#blame#use_porcelain_instead ? 'porcelain' : 'incremental',
        \ string(s:pick_available_options(a:options)),
        \])
  if !has_key(a:git, '_gita_blameobj_cache')
    let a:git._gita_blameobj_cache = s:MemoryCache.new()
  endif
  " NOTE:
  " Get cached blameobj and check if 'index' is updated from a last accessed
  " time and determine if the cached content is fresh enough.
  " But if the 'commit' seems like a hashref, trust cached blameobj while
  " constructing blameobj is really timeconsuming.
  let cached  = a:git._gita_blameobj_cache.get(cachename, {})
  let hashref = a:commit =~# '^[0-9a-zA-Z]\{40}$'
  let uptime = empty(a:commit)
        \ ? getftime(a:filename)
        \ : s:Git.getftime(a:git, 'index')
  if empty(cached) || (!hashref && (uptime == -1 || uptime > cached.uptime))
    let blameobj = s:get_blameobj(a:git, a:commit, a:filename, a:options)
    call a:git._gita_blameobj_cache.set(cachename, {
          \ 'uptime': uptime,
          \ 'blameobj': blameobj,
          \})
    return blameobj
  endif
  return cached.blameobj
endfunction

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

function! s:get_entry(index) abort
  let blamemeta = gita#command#blame#_get_blamemeta_or_fail()
  let lineinfo = get(blamemeta.lineinfos, a:index, {})
  if empty(lineinfo)
    return {}
  endif
  return deepcopy(blamemeta.chunks[lineinfo.chunkref])
endfunction
function! s:call_pseudo_command(...) abort
  let ret = s:Prompt.input('None', ':', get(a:000, 0, ''))
  redraw | echo
  if ret =~# '\v^[0-9]+$'
    call gita#command#blame#select([ret])
  elseif ret =~# '^q\%(\|u\|ui\|uit\)!\?$' || ret =~# '^clo\%(\|s\|se\)!\?$'
    try
      let blameobj = gita#command#blame#_get_blameobj_or_fail()
      let winnum_partner = gita#get_meta('content_type') ==# 'blame-navi'
            \ ? winbufnr(blameobj.view_bufnum)
            \ : winbufnr(blameobj.navi_bufnum)
      if winnum_partner != -1
        execute printf('%d%s', winnum_partner, ret)
      endif
    catch /^\%(vital: Git[:.]\|vim-gita:\)/
      call gita#util#handle_exception()
    endtry
    execute ret
  else
    execute ret
  endif
endfunction

function! gita#command#blame#call(...) abort
  let options = gita#option#cascade('blame', get(a:000, 0, {}), {
        \ 'commit': '',
        \ 'filename': '',
        \})
  let git = gita#get_or_fail()
  let commit = gita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  let filename = gita#variable#get_valid_filename(options.filename)
  let blameobj = s:get_cached_blameobj(git, commit, filename, options)
  let result = {
        \ 'commit': commit,
        \ 'filename': filename,
        \ 'blameobj': blameobj,
        \ 'options': options,
        \}
  return result
endfunction
function! gita#command#blame#open(...) abort
  let options = extend({
        \ 'anchor': 0,
        \ 'opener': '',
        \ 'selection': [],
        \ 'backward': '',
        \}, get(a:000, 0, {}))
  let opener = empty(options.opener)
        \ ? g:gita#command#blame#default_opener
        \ : options.opener
  let result = gita#command#blame#call(options)
  if options.anchor
    call s:Anchor.focus()
  endif
  " NOTE:
  " In case, do not call autocmd to prevent infinity-loop while both buffers
  " define BufReadCmd when these are already constructed.
  let guard = s:Guard.store('&eventignore')
  try
    set eventignore=BufReadCmd
    call gita#command#blame#view#_open(
          \ result.blameobj, {
          \   'opener': opener,
          \   'commit': result.commit,
          \   'filename': result.filename,
          \   'backward': options.backward,
          \})
    call gita#command#blame#navi#_open(
          \ result.blameobj, {
          \   'opener': g:gita#command#blame#navi#default_opener,
          \   'commit': result.commit,
          \   'filename': result.filename,
          \   'backward': options.backward,
          \})
  finally
    call guard.restore()
  endtry
  " NOTE:
  " Order of appearance, navi#_edit -> view#_edit, is ciritical requirement.
  call gita#command#blame#navi#_edit()
  setlocal noscrollbind
  call gita#command#blame#select(options.selection)
  normal! z.
  wincmd p
  call gita#command#blame#view#_edit()
  setlocal noscrollbind
  call gita#command#blame#select(options.selection)
  normal! z.
  wincmd p
  setlocal scrollbind
  setlocal cursorbind
  wincmd p
  setlocal scrollbind
  setlocal cursorbind
  syncbind
  " focus gita-blame-navi
  wincmd p
endfunction
function! gita#command#blame#format(blameobj, width) abort
  let progressbar = s:ProgressBar.new(
        \ len(a:blameobj.chunks), {
        \   'barwidth': 80,
        \   'statusline': 0,
        \   'prefix': 'Constructing interface: ',
        \})
  try
    return s:format_blameobj(a:blameobj, a:width, progressbar)
  finally
    call progressbar.exit()
  endtry
endfunction
function! gita#command#blame#get_pseudo_linenum(linenum) abort
  " actual -> pseudo
  let blamemeta = gita#command#blame#_get_blamemeta_or_fail()
  let lineinfos = blamemeta.lineinfos
  if a:linenum > len(lineinfos)
    let lineinfo = lineinfos[-1]
  elseif a:linenum <= 0
    let lineinfo = lineinfos[0]
  else
    let lineinfo = lineinfos[a:linenum - 1]
  endif
  return lineinfo.linenum.final
endfunction
function! gita#command#blame#get_actual_linenum(linenum) abort
  " pseudo -> actual
  let blamemeta = gita#command#blame#_get_blamemeta_or_fail()
  let linerefs = blamemeta.linerefs
  if a:linenum > len(linerefs)
    return linerefs[-1]
  elseif a:linenum <= 0
    return linerefs[0]
  else
    return linerefs[a:linenum-1]
  endif
endfunction
function! gita#command#blame#select(selection) abort
  " pseudo -> actual
  let line_start = get(a:selection, 0, 1)
  let line_end = get(a:selection, 1, line_start)
  let actual_selection = [
        \ gita#command#blame#get_actual_linenum(line_start),
        \ gita#command#blame#get_actual_linenum(line_end),
        \]
  call gita#util#select(actual_selection)
endfunction

function! gita#command#blame#_get_blameobj_or_fail() abort
  let blameobj = gita#get_meta('blameobj')
  if empty(blameobj)
    call gita#throw(printf(
          \ 'Fatal: "blameobj" is not found on %s', bufname('%'),
          \))
  endif
  return blameobj
endfunction
function! gita#command#blame#_get_blamemeta_or_fail() abort
  let blameobj = gita#command#blame#_get_blameobj_or_fail()
  if !has_key(blameobj, 'blamemeta')
    call gita#throw(printf(
          \ 'Fatal: "blameobj" does not have "blamemeta" attribute on %s',
          \ bufname('%'),
          \))
  endif
  return blameobj.blamemeta
endfunction
function! gita#command#blame#_set_pseudo_separators(separators, ...) abort
  let bufnum = bufnr('%')
  execute printf('sign unplace * buffer=%d', bufnum)
  for linenum in a:separators
    execute printf(
          \ 'sign place %d line=%d name=GitaPseudoSeparatorSign buffer=%d',
          \ linenum, linenum, bufnum,
          \)
  endfor
endfunction
function! gita#command#blame#_define_actions() abort
  let action = gita#action#define(function('s:get_entry'))
  function! action.actions.blame_command(candidates, ...) abort
    call s:call_pseudo_command()
  endfunction
  function! action.actions.blame_echo(candidates, ...) abort
    let candidate = get(a:candidates, 0, {})
    if empty(candidate)
      return
    endif
    let commit   = gita#get_meta('commit')
    let filename = gita#get_meta('filename')
    echo '=== Current ==='
    echo 'Commit:   ' . commit
    echo 'Filename: ' . filename
    echo '===  Chunk  ==='
    echo 'Summary:  ' . candidate.summary
    echo 'Author:   ' . candidate.author
    echo 'Boundary: ' . (get(candidate, 'boundary') ? 'boundary' : '')
    echo 'Commit:   ' . candidate.revision
    echo 'Previous: ' . get(candidate, 'previous', '')
    echo 'Filename: ' . candidate.filename
    echo 'Line (O): ' . candidate.linenum.original
    echo 'Line (F): ' . candidate.linenum.final
  endfunction
  function! action.actions.blame_enter(candidates, ...) abort
    let candidate = get(a:candidates, 0, {})
    if empty(candidate)
      return
    endif
    let commit = gita#get_meta('commit')
    if candidate.revision ==# commit
      if !has_key(candidate, 'previous')
        call gita#throw(
              \ 'Cancel:',
              \ printf('A commit %s has no previous commit', candidate.revision),
              \)
      endif
      let [revision, filename] = split(candidate.previous)
      if revision ==# commit
        call gita#throw(
              \ 'Cancel:',
              \ printf('A commit %s is a boundary commit', candidate.revision),
              \)
      endif
    else
      let revision = candidate.revision
      let filename = candidate.filename
    endif
    let linenum = gita#command#blame#get_pseudo_linenum(line('.'))
    let linenum = candidate.linenum.original + (linenum - candidate.linenum.final)
    let winnum = winnr()
    redraw | echo printf('Opening a blame content of "%s" in %s', filename, revision)
    call gita#command#blame#open({
          \ 'backward': join([
          \   commit,
          \   gita#get_meta('filename'),
          \ ], ':'),
          \ 'commit': revision,
          \ 'filename': filename,
          \ 'selection': [linenum],
          \})
    execute printf('%dwincmd w', winnum)
    redraw | echo
  endfunction
  function! action.actions.blame_backward(candidates, ...) abort
    let backward = gita#get_meta('backward')
    if empty(backward)
      call gita#throw(
            \ 'Cancel:',
            \ 'No backward blame found',
            \)
    endif
    let [revision, filename] = split(backward, ':', 1)
    let winnum = winnr()
    redraw | echo printf('Opening a blame content of "%s" in %s', filename, revision)
    call gita#command#blame#open({
          \ 'commit': revision,
          \ 'filename': filename,
          \ 'selection': [
          \   gita#command#blame#get_pseudo_linenum(line('.')),
          \ ],
          \})
    execute printf('%dwincmd w', winnum)
    redraw | echo
  endfunction

  nnoremap <silent><buffer> <Plug>(gita-blame-command)
        \ :<C-u>call gita#action#call('blame_command')<CR>
  nnoremap <silent><buffer> <Plug>(gita-blame-echo)
        \ :<C-u>call gita#action#call('blame_echo')<CR>
  nnoremap <silent><buffer> <Plug>(gita-blame-enter)
        \ :<C-u>call gita#action#call('blame_enter')<CR>
  nnoremap <silent><buffer> <Plug>(gita-blame-backward)
        \ :<C-u>call gita#action#call('blame_backward')<CR>

  nmap <buffer> : <Plug>(gita-blame-command)

  return action
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita blame',
          \ 'description': 'Show what revision and author last modified each line of a file',
          \ 'complete_unknown': function('gita#variable#complete_filename'),
          \ 'unknown_description': 'filename',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ 'commit', [
          \   'A commit which you want to blame.',
          \   'If nothing is specified, it show a blame of HEAD.',
          \   'If <commit> is specified, it show a blame of the named <commit>.',
          \ ], {
          \   'complete': function('gita#variable#complete_commit'),
          \ })
    " TODO: Add more arguments
  endif
  return s:parser
endfunction
function! gita#command#blame#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gita#option#assign_commit(options)
  call gita#option#assign_filename(options)
  call gita#option#assign_selection(options)
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#blame#default_options),
        \ options,
        \)
  call gita#command#blame#open(options)
endfunction
function! gita#command#blame#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

highlight default link GitaPseudoSeparator GitaPseudoSeparatorDefault
highlight GitaPseudoSeparatorDefault term=underline cterm=underline ctermfg=8 gui=underline guifg=#363636
if !exists('s:_sign_defined')
  sign define GitaPseudoSeparatorSign texthl=SignColumn linehl=GitaPseudoSeparator
  let s:_sign_defined = 1
endif

call gita#util#define_variables('command#blame', {
      \ 'default_options': {},
      \ 'default_opener': 'tabnew',
      \ 'use_porcelain_instead': 0,
      \})
