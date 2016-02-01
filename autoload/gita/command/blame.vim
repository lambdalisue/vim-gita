let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:DateTime = s:V.import('DateTime')
let s:String = s:V.import('Data.String')
let s:Path = s:V.import('System.Filepath')
let s:MemoryCache = s:V.import('System.Cache.Memory')
let s:Prompt = s:V.import('Vim.Prompt')
let s:Git = s:V.import('Git')
let s:GitParser = s:V.import('Git.Parser')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')
let s:ProgressBar = s:V.import('ProgressBar')

function! s:pick_available_options(options) abort
  let options = s:Dict.pick(a:options, [
        \ 'porcelain',
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
    return s:GitParser.parse_blame_to_chunks(a:content, progressbar)
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
  let options['porcelain'] = 1
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
  return blameobj
endfunction
function! s:get_cached_blameobj(git, commit, filename, options) abort
  let cachename = join([
        \ a:commit, a:filename,
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
  let uptime = s:Git.getftime(a:git, 'index')
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
  let chunk = a:chunks[-1]
  return chunk.linenum.final + get(chunk.linenum, 'nlines', 1)
endfunction
function! s:build_chunkinfo(chunk, width, now, whitespaces) abort
  let summary = s:String.wrap(a:chunk.summary, a:width)
  let revision = a:chunk.revision[:6]
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
  let epilogue = author_info . a:whitespaces[8+len(author_info):] . revision
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
    let n_contents = len(chunk.contents)
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
      call add(view_content, get(chunk.contents, cursor, ''))
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

function! s:define_plugin_mappings() abort
  nnoremap <silent><buffer> <Plug>(gita-pseudo-command)
        \ :call gita#command#blame#perform_pseudo_command()<CR>
endfunction
function! s:define_default_mappings() abort
  nmap <buffer> : <Plug>(gita-pseudo-command)
endfunction
function! s:display_pseudo_separators(separators, expr) abort
  let bufnum = bufnr(a:expr)
  execute printf('sign unplace * buffer=%d', bufnum)
  for linenum in a:separators
    execute printf(
          \ 'sign place %d line=%d name=GitaPseudoSeparatorSign buffer=%d',
          \ linenum, linenum, bufnum,
          \)
  endfor
endfunction

function! gita#command#blame#call(...) abort
  let options = gita#option#init('blame', get(a:000, 0, {}), {
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
        \ 'opener': '',
        \ 'selection': [],
        \}, get(a:000, 0, {}))
  let opener = empty(options.opener)
        \ ? g:gita#command#blame#default_opener
        \ : options.opener
  let result = gita#command#blame#call(options)
  " NOTE:
  " In case, do not call autocmd to prevent infinity-loop while both buffers
  " define BufReadCmd when these are already constructed.
  call gita#command#blame#view#_open(
        \ result.blameobj, {
        \   'opener': opener,
        \   'commit': result.commit,
        \   'filename': result.filename,
        \})
  call gita#command#blame#navi#_open(
        \ result.blameobj, {
        \   'opener': g:gita#command#blame#navi#default_opener,
        \   'commit': result.commit,
        \   'filename': result.filename,
        \})
  " NOTE:
  " Order of appearance, navi#_edit -> view#_edit, is ciritical requirement.
  call gita#command#blame#navi#_edit()
  call gita#command#blame#select(options.selection)
  call s:define_plugin_mappings()
  call s:define_default_mappings()
  setlocal noscrollbind
  normal! z.
  wincmd p
  call gita#command#blame#view#_edit()
  call gita#command#blame#select(options.selection)
  call s:define_plugin_mappings()
  call s:define_default_mappings()
  setlocal noscrollbind
  normal! z.
  wincmd p
  setlocal scrollbind
  setlocal cursorbind
  wincmd p
  setlocal scrollbind
  setlocal cursorbind
  syncbind
endfunction
function! gita#command#blame#format(blameobj, width) abort
  let options = extend({}, get(a:000, 0, {}))
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

function! gita#command#blame#get_blameobj_or_fail() abort
  let blameobj = gita#get_meta('blameobj')
  if empty(blameobj)
    call gita#throw(printf(
          \ 'Fatal: "blameobj" is not found on %s', bufname('%'),
          \))
  endif
  return blameobj
endfunction
function! gita#command#blame#get_blamemeta_or_fail() abort
  let blameobj = gita#command#blame#get_blameobj_or_fail()
  if !has_key(blameobj, 'blamemeta')
    call gita#throw(printf(
          \ 'Fatal: "blameobj" does not have "blamemeta" attribute on %s',
          \ bufname('%'),
          \))
  endif
  return blameobj.blamemeta
endfunction
function! gita#command#blame#get_pseudo_linenum(linenum) abort
  " actual -> pseudo
  let blamemeta = gita#command#blame#get_blamemeta_or_fail()
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
  let blamemeta = gita#command#blame#get_blamemeta_or_fail()
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
  let blamemeta = gita#command#blame#get_blamemeta_or_fail()
  let line_start = get(a:selection, 0, 1)
  let line_end = get(a:selection, 1, line_start)
  let actual_selection = [
        \ gita#command#blame#get_actual_linenum(line_start),
        \ gita#command#blame#get_actual_linenum(line_end),
        \]
  call gita#util#select(actual_selection)
endfunction
function! gita#command#blame#perform_pseudo_command(...) abort
  let ret = s:Prompt.input('None', ':', get(a:000, 0, ''))
  if ret =~# '\v^[0-9]+$'
    call gita#command#blame#selection([ret])
  else
    redraw
    execute ret
  endif
endfunction
function! gita#command#blame#display_pseudo_separators(separators, ...) abort
  let bufnum = bufnr('%')
  execute printf('sign unplace * buffer=%d', bufnum)
  for linenum in a:separators
    execute printf(
          \ 'sign place %d line=%d name=GitaPseudoSeparatorSign buffer=%d',
          \ linenum, linenum, bufnum,
          \)
  endfor
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita blame',
          \ 'description': 'Show what revision and author last modified each line of a file',
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
    call s:parser.add_argument(
          \ 'filename', [
          \   'A filename which you want to blame.',
          \   'A filename of the current buffer is used when omited.',
          \ ],
          \)
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
      \ 'navigation_winwidth': 50,
      \ 'enable_pseudo_separator': 1,
      \ 'short_revision_length': 7,
      \})
