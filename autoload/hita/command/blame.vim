let s:V = hita#vital()
let s:DateTime = s:V.import('DateTime')
let s:String = s:V.import('Data.String')
let s:Cache = s:V.import('System.Cache.Memory')
let s:BlameParser = s:V.import('VCS.Git.BlameParser')
let s:ArgumentParser = s:V.import('ArgumentParser')
let s:SHORT_REVISION = 7
let s:NAVI_WINWIDTH = 50

function! s:pick_available_options(options) abort
  let options = s:Dict.pick(a:options, [
        \ 'porcelain',
        \])
  return options
endfunction
function! s:get_blame_content(hita, commit, filenames, options) abort
  let options = s:pick_available_options(a:options)
  let options['commit'] = a:commit
  if !empty(a:filenames)
    let options['--'] = map(
          \ copy(a:filenames),
          \ 'a:hita.get_absolute_path(v:val)',
          \)
  endif
  let result = hita#operation#exec(a:hita, 'blame', options)
  if result.status
    call hita#throw(result.stdout)
  endif
  return split(result.stdout, '\r\?\n')
endfunction

function! s:string_wrap(str, width) abort
  return map(
        \ s:String.wrap(a:str, a:width - 1),
        \ 'substitute(v:val, "^\s*\|\s*$", "", "g")',
        \)
endfunction
function! s:string_truncate(str, width) abort
  return strdisplaywidth(a:str) > a:width
        \ ? s:String.truncate(a:str, a:width - 4) . '...'
        \ : a:str
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
function! s:format_chunk(chunk, width, now, options) abort
  let options = extend({
        \ 'wrap': 0,
        \ 'extra_info': 0,
        \}, a:options)
  let summary = options.wrap
        \ ? s:string_wrap(a:chunk.summary, a:width)
        \ : s:string_truncate(a:chunk.summary, a:width)
  let revision = a:chunk.revision[:(s:SHORT_REVISION-1)]
  let author = a:chunk.author
  let timestr = s:format_timestamp(
        \ a:chunk.author_time,
        \ a:chunk.author_tz,
        \ a:now,
        \)
  let author_info = author . ' authored ' . timestr
  let whitespaces = repeat(' ', a:width - (s:SHORT_REVISON + 1))
  let formatted = summary + [
        \ author_info . whitespaces[len(author_info):] . revision
        \]
  if options.extra_info && has_key(a:chunk, 'previous')
    let prefix = 'Prev: '
    let previous_revision = a:chunk.previous[:(s:SHORT_REVISON - 1)]
    let spacer = repeat(' ', a:width - (s:SHORT_REVISON + 1) - len(author_info))
    let formatted += [
          \ whitespaces[len(prefix):] . prefix . previous_revision,
          \]
  elseif options.extra_info && get(a:chunk, 'boundary')
    let formatted += [
          \ repeat(' ', a:width - 9) . 'BOUNDARY',
          \]
  endif
  return formatted
endfunction
function! s:parse_blame(hita, content, width) abort
  let result = s:BlameParser.parse_to_chunks(join(a:content, "\n"))
  let now = s:DateTime.now()
  let cache = s:Cache.new()
  let enable_pseudo_separator = g:hita#command#blame#enable_pseudo_separator
  let min_chunk_lines = enable_pseudo_separator ? 2 : 1
  let navi_content = []
  let view_content = []
  let lineinfos = []
  let linerefs = []
  let separators = []
  let linenum = 1
  let k = result.chunks[-1].linenum
  let linenum_width = len(k.final + get(k, 'nlines', 1))
  let linenum_format = printf('%%%ds %%s', linenum_width)
  let navi_width = a:width - linenum_width - 1
  let revisions = result.revisions
  for chunk in result.chunks
    call extend(chunk, revisions[chunk.revision])
    let n_contents = len(chunk.contents)
    let is_wrapable = n_contents > 2
    let cache_name = chunk.revision . is_wrapable
    if !cache.has(cache_name)
      let formatted_chunk = s:format_chunk(chunk, navi_width, now, {
            \ 'wrap': is_wrapable,
            \ 'extra_info': n_contents > 3,
            \})
      call cache.set(cache_name, formatted_chunk)
    else
      let formatted_chunk = cache.get(cache_name)
    endif
    let n_lines = max([min_chunk_lines, n_contents])
    for cursor in range(n_lines)
      if cursor < n_contents
        call add(linerefs, linenum)
      endif
      call add(navi_content, printf(linenum_format,
            \ cursor >= n_contents ? '' : chunk.linenum.final + cursor,
            \ get(formatted_chunk, cursor, ''),
            \))
      call add(view_content, get(chunk.contents, cursor, ''))
      call add(lineinfos, {
            \ 'chunkref': chunk.index,
            \ 'linenum': {
            \   'original': chunk.linenum.original + cursor,
            \   'final': chunk.linenum.final + cursor,
            \ },
            \})
      let linenum += 1
    endfor
    " Add a pseudo separator line
    if !enable_pseudo_separator
      continue
    endif
    call add(navi_content, '')
    call add(view_content, '')
    call add(lineinfos, {
          \ 'chunkref': chunk.index,
          \ 'linenum': {
          \   'original': chunk.linenum.original + (n_lines - 1),
          \   'final': chunk.linenum.final + (n_lines - 1),
          \ },
          \})
    call add(separators, linenum)
    let linenum += 1
  endfor
  let offset = enable_pseudo_separator ? -2 : -1
  let blame = {
        \ 'chunks': result.chunks,
        \ 'lineinfos': lineinfos[:offset],
        \ 'linerefs': linerefs,
        \ 'separators': empty(separators) ? [] : separators[:offset],
        \ 'navi_content': navi_content[:offset],
        \ 'view_content': view_content[:offset],
        \}
  return blame
endfunction


function! hita#command#status#bufname(prefix, ...) abort
  let options = extend({
        \ 'filenames': [],
        \}, get(a:000, 0, {}))
  let hita = hita#core#get()
  try
    call hita.fail_on_disabled()
  catch /^vim-hita:/
    call hita#util#handle_exception(v:exception)
    return
  endtry
  return printf('hita-blame:%s:%s%s',
        \ hita.get_repository_name(),
        \ a:prefix,
        \ empty(options.filenames) ? '' : ':partial'
        \)
endfunction
function! hita#command#blame#call(...) abort
  let options = extend({
        \ 'commit': '',
        \ 'filenames': [],
        \}, get(a:000, 0, {}))
  let hita = hita#core#get()
  try
    call hita.fail_on_disabled()
    let commit = hita#variable#get_valid_range(options.commit, {
          \ '_allow_empty': 1,
          \})
    if !empty(options.filenames)
      let filenames = map(
            \ copy(options.filenames),
            \ 'hita#variable#get_valid_filename(v:val)',
            \)
    else
      let filenames = []
    endif
    let content = s:get_diff_content(hita, commit, filenames, options)
    let result = {
          \ 'commit': commit,
          \ 'filenames': filenames,
          \ 'content': content,
          \}
    return result
  catch /^vim-hita:/
    call hita#util#handle_exception(v:exception)
    return {}
  endtry
endfunction
function! hita#command#blame#open(...) abort
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  if hita#core#get_meta('content_type', '') ==# 'blame'
    let options = extend(options, hita#core#get_meta('options', {}))
  endif
  let options['porcelain'] = 1
  let result = hita#command#blame#call(options)
  if empty(result)
    return
  endif
  let hita = hita#core#get()
  " NOTE:
  " 2 columns for signs
  let blame = s:parse_blame(hita, result.content, s:NAVI_WINWIDTH - 2)
  let opener = empty(options.opener)
        \ ? g:hita#command#blame#default_opener
        \ : options.opener
  let bufname_navi = hita#command#blame#bufname('navi', options)
  let bufname_view = hita#command#blame#bufname('view', options)
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:hita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Hita blame',
          \ 'description': 'Apply patch(es) to the repository',
          \ 'complete_unknown': function('hita#variable#complete_filename'),
          \ 'unknown_description': 'filenames',
          \ 'complete_threshold': g:hita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--cached',
          \ 'Directory blame the pathc(es) to INDEX', {
          \})
    " TODO: Add more arguments
  endif
  return s:parser
endfunction
function! hita#command#blame#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  if !empty(options.__unknown__)
    let options.filenames = options.__unknown__
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:hita#command#blame#default_options),
        \ options,
        \)
  call hita#command#blame#call(options)
endfunction
function! hita#command#blame#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call hita#define_variables('command#blame', {
      \ 'default_options': {},
      \ 'default_opener': 'edit',
      \ 'enable_pseudo_separator': 1,
      \})
