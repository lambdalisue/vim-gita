let s:save_cpoptions = &cpoptions
set cpoptions&vim

let s:T = gita#import('DateTime')
let s:L = gita#import('Data.List')
let s:D = gita#import('Data.Dict')
let s:S = gita#import('Data.String')
let s:P = gita#import('System.Filepath')
let s:C = gita#import('System.Cache.Memory')
let s:B = gita#import('VCS.Git.BlameParser')
let s:A = gita#import('ArgumentParser')

let s:const = {}
let s:const.filetype = 'gita-blame-navi'
let s:const.shortrev = 7

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

let s:blame_history = { 'history': [] }
function! s:blame_history.add() abort " {{{
  let abspath   = gita#meta#get('filename')
  let commit    = gita#meta#get('commit')
  let blamemeta = gita#meta#get('blame#meta')
  let lnum      = line('.')
  let col       = col('.')
  let info = {
        \ 'path': abspath,
        \ 'commit': commit,
        \ 'blamemeta': blamemeta,
        \ 'lnum': lnum,
        \ 'col': col,
        \}
  call s:L.push(self.history, info)
endfunction " }}}
function! s:blame_history.pop() abort " {{{
  if len(self.history) == 0
    return {}
  endif
  return s:L.pop(self.history)
endfunction " }}}

let s:navi_actions = {}
function! s:navi_actions.blame_info(candidates, options, config) abort " {{{
  let candidate = get(a:candidates, 0, {})
  if empty(candidate)
    return
  endif
  let formatted_chunk = s:format_chunk(candidate.chunk, 80, 1, s:T.now(), 1)
  echo join(formatted_chunk, "\n")
endfunction " }}}
function! s:navi_actions.blame_enter(candidates, options, config) abort " {{{
  let candidate = get(a:candidates, 0, {})
  if empty(candidate)
    return
  endif
  let abspath = gita#utils#sget([a:options, candidate], 'path')
  let relpath = s:P.relpath(abspath)
  let commit = gita#utils#sget([a:options, candidate], 'commit')
  if commit ==# gita#meta#get('commit')
    call gita#utils#prompt#info('This is a boundary commit')
    return
  endif
  call gita#utils#prompt#info(printf(
        \ 'Entering %s of %s...',
        \ commit, relpath,
        \))
  call s:get_history().add()
  call gita#utils#anchor#focus()
  call gita#features#blame#show({
        \ 'file': abspath,
        \ 'commit': commit,
        \ 'line_start': gita#utils#sget([a:options, candidate], 'line_start'),
        \ 'line_end': gita#utils#sget([a:options, candidate], 'line_end'),
        \ 'range': get(a:options, 'range', 'tabpage'),
        \})
  redraw | echo
endfunction " }}}
function! s:navi_actions.blame_leave(candidates, options, config) abort " {{{
  let info = s:get_history().pop()
  if empty(info)
    call gita#utils#prompt#info('No blame navigation history exists')
    return
  endif
  let abspath = gita#meta#get('filename')
  let relpath = s:P.relpath(abspath)
  let commit = gita#meta#get('commit')
  call gita#utils#prompt#info(printf(
        \ 'Leaving %s of %s...',
        \ commit, relpath,
        \))
  call s:view_show(info.path, info.commit, info.blamemeta)
  let VIEW_bufnr = bufnr('%')
  call s:navi_show(info.path, info.commit, info.blamemeta)
  let NAVI_bufnr = bufnr('%')
  " set partner bufnr
  call setbufvar(VIEW_bufnr, '_gita_blame_partner_bufnr', NAVI_bufnr)
  call setbufvar(NAVI_bufnr, '_gita_blame_partner_bufnr', VIEW_bufnr)
  keepjumps call setpos('.', [0, info.lnum, info.col, 0])
  normal z.
  syncbind
  redraw | echo
endfunction " }}}
function! s:navi_actions.blame_refresh(candidates, options, config) abort " {{{
  let abspath   = gita#meta#get('filename')
  let commit    = gita#meta#get('commit')
  let blamemeta = gita#meta#get('blame#meta')
  let lnum      = line('.')
  let col       = col('.')
  let NAVI_bufnr = bufnr('%')
  call s:view_show(abspath, commit, blamemeta)
  let VIEW_bufnr = bufnr('%')
  " set partner bufnr
  call setbufvar(VIEW_bufnr, '_gita_blame_partner_bufnr', NAVI_bufnr)
  call setbufvar(NAVI_bufnr, '_gita_blame_partner_bufnr', VIEW_bufnr)
  keepjumps wincmd p
  vertical resize 50
  keepjumps call setpos('.', [0, lnum, col, 0])
  normal z.
  syncbind
  redraw | echo
endfunction " }}}
function! s:navi_actions.blame_prev_chunk(candidates, options, config) abort " {{{
  let candidate = get(a:candidates, 0, {})
  if empty(candidate)
    return
  endif
  let blamemeta = gita#meta#get('blame#meta')
  let chunks = blamemeta.chunks
  let chunk = candidate.chunk
  if chunk.index == 0
    call gita#utils#prompt#warn('This is a first chunk')
    return
  endif
  let prev_chunk = chunks[chunk.index - 1]
  call gita#features#blame#goto(prev_chunk.linenum.final)
endfunction " }}}
function! s:navi_actions.blame_next_chunk(candidates, options, config) abort " {{{
  let candidate = get(a:candidates, -1, {})
  if empty(candidate)
    return
  endif
  let blamemeta = gita#meta#get('blame#meta')
  let chunks = blamemeta.chunks
  let chunk = candidate.chunk
  if chunk.index >= len(chunks)
    call gita#utils#prompt#warn('This is a last chunk')
    return
  endif
  let next_chunk = chunks[chunk.index + 1]
  call gita#features#blame#goto(next_chunk.linenum.final)
endfunction " }}}
function! s:navi_actions.browse(candidates, options, config) abort " {{{
  let options = deepcopy(a:options)
  let options.scheme = get(options, 'scheme', 'blame')
  let options.commit = gita#meta#get('commit', '')
  let range = get(options, '__range__', [])
  let line_start = get(options, 'line_start', get(range, 0, 0))
  let line_end = get(options, 'line_end', get(range, 1, 0))
  let offset = line_end - line_start
  let options.line_start = gita#features#blame#get_pseudo_linenum(line_start)
  let options.line_end = options.line_start + offset
  call call('gita#features#browse#action', [a:candidates, options, a:config])
endfunction " }}}
function! s:navi_actions.open(candidates, options, config) abort " {{{
  let options = deepcopy(a:options)
  let options.opener = get(options, 'opener', printf('topleft %d split', &previewheight))
  call call('gita#features#file#action', [a:candidates, options, a:config])
endfunction " }}}
function! s:navi_actions.edit(candidates, options, config) abort " {{{
  let options = extend(a:options, {
        \ 'commit': 'WORKTREE',
        \})
  let options.opener = get(options, 'opener', printf('topleft %d split', &previewheight))
  call call('gita#features#file#action', [a:candidates, options, a:config])
endfunction " }}}
function! s:navi_actions.diff(candidates, options, config) abort " {{{
  let options = deepcopy(a:options)
  let options.opener = get(options, 'opener', printf('topleft %d split', &previewheight))
  call call('gita#features#diff#action', [a:candidates, options, a:config])
endfunction " }}}

function! s:format_timestamp(timestamp, timezone, now) abort " {{{
  let datetime  = s:T.from_unix_time(a:timestamp, a:timezone)
  let timedelta = datetime.delta(a:now)
  if timedelta.duration().months() < 3
    return timedelta.about()
  elseif datetime.year() == a:now.year()
    return 'on ' . datetime.strftime('%d %b')
  else
    return 'on ' . datetime.strftime('%d %b, %Y')
  endif
endfunction " }}}
function! s:format_chunk(chunk, width, wrap, now, is_detail) abort " {{{
  if a:wrap
    let summary = map(
          \ s:S.wrap(a:chunk.summary, a:width - 1),
          \ 'substitute(v:val, "\v%(^\s+|\s+$)", "", "g")',
          \)
  else
    let summary = s:S.truncate_skipping(
          \ a:chunk.summary,
          \ a:width - 2,
          \ 3,
          \ '...',
          \)
  endif
  let revision = a:chunk.revision[:(s:const.shortrev - 1)]
  let author = a:chunk.author
  let timestr = s:format_timestamp(
        \ a:chunk.author_time,
        \ a:chunk.author_tz,
        \ a:now,
        \)
  let author_info = printf('%s authored %s', author, timestr)
  let formatted = s:L.flatten([
        \ summary,
        \ printf('%s%s%s',
        \   author_info,
        \   repeat(' ', a:width - (s:const.shortrev + 1) - len(author_info)),
        \   revision,
        \ )
        \])
  if a:is_detail && has_key(a:chunk, 'previous')
    let prefix = 'Prev: '
    call add(formatted,
          \ printf('%s%s%s',
          \   repeat(' ', a:width - (s:const.shortrev + 1) - len(prefix)),
          \   prefix,
          \   a:chunk.previous[:(s:const.shortrev - 1)],
          \ )
          \)
  elseif a:is_detail && get(a:chunk, 'boundary')
    call add(formatted,
          \ printf('%s%s',
          \   repeat(' ', a:width - 9),
          \   'BOUNDARY',
          \ )
          \)
  endif
  return formatted
endfunction " }}}
function! s:format_chunks(gita, stdout, width) abort " {{{
  let result = s:B.parse_to_chunks(a:stdout)
  let now = s:T.now()
  let cache = s:C.new()
  let min_chunk_lines = g:gita#features#blame#enable_pseudo_separator ? 2 : 1
  let NAVI = []
  let VIEW = []
  let lineinfos = []
  let linerefs = []
  let separators = []
  let linenum = 1
  let max_linenum_digit = len(result.chunks[-1].linenum.final)
  let linenum_format = printf('%%%ds %%s', max_linenum_digit)
  for chunk in result.chunks
    call extend(chunk, result.revisions[chunk.revision])
    let chunk.filename = a:gita.git.get_absolute_path(chunk.filename)
    " get or create a formatted chunk
    let n_contents  = len(chunk.contents)
    let is_wrapable = n_contents > 2
    let cache_name  = printf('%s%d', chunk.revision, is_wrapable)
    if !cache.has(cache_name)
      let formatted_chunk = s:format_chunk(chunk, a:width - max_linenum_digit - 1, is_wrapable, now, n_contents > 3)
      call cache.set(cache_name, formatted_chunk)
    else
      let formatted_chunk = cache.get(cache_name)
    endif
    " apply formatted chunk and contents
    let n_lines = max([min_chunk_lines, n_contents])
    for i in range(n_lines)
      if i < n_contents
        call add(linerefs, linenum)
      endif
      call add(NAVI, printf(linenum_format,
            \ i >= n_contents ? '' : chunk.linenum.final + i ,
            \ get(formatted_chunk, i, ''))
            \)
      call add(VIEW, get(chunk.contents, i, ''))
      call add(lineinfos, {
            \ 'chunkref': chunk.index,
            \ 'linenum': {
            \   'original': chunk.linenum.original + i,
            \   'final': chunk.linenum.final + i,
            \ },
            \})
      let linenum += 1
    endfor
    " Add a pseudo separator line
    if g:gita#features#blame#enable_pseudo_separator
      call add(NAVI, '')
      call add(VIEW, '')
      call add(lineinfos, {
            \ 'chunkref': chunk.index,
            \ 'linenum': {
            \   'original': chunk.linenum.original + (n_lines - 1),
            \   'final': chunk.linenum.final + (n_lines - 1),
            \ },
            \})
      call add(separators, linenum)
      let linenum += 1
    endif
  endfor
  let offset = g:gita#features#blame#enable_pseudo_separator ? -2 : -1
  let meta = {
        \ 'contents': {
        \   'NAVI': NAVI[:offset],
        \   'VIEW': VIEW[:offset],
        \ },
        \ 'chunks': result.chunks,
        \ 'lineinfos': lineinfos[:offset],
        \ 'linerefs': linerefs,
        \ 'separators': empty(separators) ? [] : separators[:offset],
        \}
  return meta
endfunction " }}}
function! s:display_pseudo_separators(blamemeta) abort " {{{
  let bufnum = bufnr('%')
  execute printf('sign unplace * buffer=%d', bufnum)
  for linenum in a:blamemeta.separators
    execute printf(
          \ 'sign place %d line=%d name=GitaPseudoSeparatorSign buffer=%d',
          \ linenum, linenum, bufnum,
          \)
  endfor
endfunction " }}}
function! s:get_history() abort " {{{
  let w:_gita_blame_history = get(w:, '_gita_blame_history', deepcopy(s:blame_history))
  return w:_gita_blame_history
endfunction " }}}
function! s:pseudo_command(...) abort " {{{
  let ret = input(':', get(a:000, 0, ''))
  if ret =~# '\v^[0-9]+$'
    call gita#features#blame#goto(ret)
  elseif ret =~# '^q$'
    call gita#features#blame#quit()
  else
    redraw
    execute ret
  endif
endfunction " }}}

function! s:view_show(abspath, commit, blamemeta, ...) abort " {{{
  let options = get(a:000, 0, {})
  let gita = gita#get(a:abspath)
  let relpath = gita.git.get_relative_path(a:abspath)
  let bufname = gita#utils#buffer#bufname(
        \ 'BLAME',
        \ len(a:commit) == 40 ? a:commit[:(s:const.shortrev - 1)] : a:commit,
        \ relpath)
  silent call gita#utils#buffer#open(bufname, {
        \ 'group': 'blame_view',
        \ 'range': gita#utils#eget(options, 'range', 'tabpage'),
        \ 'opener': gita#utils#eget(options, 'opener', 'rightbelow vsplit'),
        \})
  setlocal buftype=nofile noswapfile nobuflisted
  setlocal nomodifiable
  setlocal nowrap nofoldenable foldcolumn=0
  setlocal scrollbind scrollopt=ver
  setlocal nonumber
  if exists('&cursorbind')
    setlocal cursorbind
  endif
  call gita#meta#extend({
        \ 'commit': a:commit,
        \ 'filename': a:abspath,
        \ 'blame#meta': a:blamemeta,
        \})
  call gita#utils#buffer#update(a:blamemeta.contents.VIEW)
  call s:display_pseudo_separators(a:blamemeta)
  call s:view_define_mappings()
  if g:gita#features#blame#enable_default_mappings || g:gita#features#blame#enable_default_view_mappings
    call s:view_define_default_mappings()
  endif
endfunction " }}}
function! s:view_define_mappings() abort " {{{
  nnoremap <silent><buffer> <Plug>(gita-action-blame-command)
        \ :<C-u>call <SID>pseudo_command()<CR>
endfunction " }}}
function! s:view_define_default_mappings() abort " {{{
  nmap <buffer> : <Plug>(gita-action-blame-command)
endfunction " }}}
function! s:navi_get_candidates(start, end, ...) abort " {{{
  let blamemeta = gita#meta#get('blame#meta')
  let lineinfo = blamemeta.lineinfos[a:start - 1]
  let chunk = blamemeta.chunks[lineinfo.chunkref]
  let filename = chunk.filename
  let revision = chunk.revision
  let previous = get(chunk, 'previous', '')
  if revision ==# gita#meta#get('commit') && !empty(previous)
    let [revision, filename] = split(previous, '\s')
  endif
  let candidate = gita#action#new_candidate(
        \ filename,
        \ revision, {
        \ 'line_start': lineinfo.linenum.original,
        \ 'line_end': lineinfo.linenum.original,
        \ 'chunk': chunk,
        \})
  return [candidate]
endfunction " }}}
function! s:navi_show(abspath, commit, blamemeta, ...) abort " {{{
  let options = get(a:000, 0, {})
  let gita = gita#get(a:abspath)
  let relpath = gita.git.get_relative_path(a:abspath)
  let bufname = gita#utils#buffer#bufname(
        \ 'BLAME', 'NAVI',
        \ len(a:commit) == 40 ? a:commit[:(s:const.shortrev - 1)] : a:commit,
        \ relpath)
  silent call gita#utils#buffer#open(bufname, {
        \ 'group': 'blame_navi',
        \ 'range': gita#utils#eget(options, 'range', 'tabpage'),
        \ 'opener': gita#utils#eget(options, 'opener', 'leftabove 50 vsplit'),
        \})
  execute printf('setfiletype %s', s:const.filetype)
  setlocal buftype=nofile noswapfile nobuflisted
  setlocal nomodifiable
  setlocal nowrap nofoldenable foldcolumn=0
  setlocal nonumber nolist
  setlocal scrollbind scrollopt=ver
  if exists('&cursorbind')
    setlocal cursorbind
  endif
  call gita#meta#extend({
        \ 'commit': a:commit,
        \ 'filename': a:abspath,
        \ 'blame#meta': a:blamemeta,
        \})
  call gita#action#extend_actions(s:navi_actions)
  call gita#action#register_get_candidates(function('s:navi_get_candidates'))
  call gita#utils#buffer#update(a:blamemeta.contents.NAVI)
  call s:display_pseudo_separators(a:blamemeta)
  call s:navi_define_mappings()
  if g:gita#features#blame#enable_default_mappings || g:gita#features#blame#enable_default_navi_mappings
    call s:navi_define_default_mappings()
  endif
endfunction " }}}
function! s:navi_define_mappings() abort " {{{
  call gita#monitor#define_mappings()
  unmap <buffer> <Plug>(gita-action-help-s)

  nnoremap <silent><buffer> <Plug>(gita-action-blame-info)
        \ :<C-u>call gita#action#call('blame_info')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-blame-enter)
        \ :<C-u>call gita#action#call('blame_enter')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-blame-leave)
        \ :<C-u>call gita#action#call('blame_leave')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-blame-refresh)
        \ :<C-u>call gita#action#call('blame_refresh')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-blame-prev-chunk)
        \ :<C-u>call gita#action#call('blame_prev_chunk')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-blame-next-chunk)
        \ :<C-u>call gita#action#call('blame_next_chunk')<CR>

  nnoremap <silent><buffer> <Plug>(gita-action-blame-command)
        \ :<C-u>call <SID>pseudo_command()<CR>
endfunction " }}}
function! s:navi_define_default_mappings() abort " {{{
  call gita#monitor#define_default_mappings()
  unmap <buffer> ?s
  unmap <buffer> q

  nmap <buffer> g<C-g> <Plug>(gita-action-blame-info)
  nmap <buffer> <CR>  <Plug>(gita-action-blame-enter)
  nmap <buffer> <BS> <Plug>(gita-action-blame-leave)
  nmap <buffer> <C-l> <Plug>(gita-action-blame-refresh)

  nmap <buffer> ]c <Plug>(gita-action-blame-next-chunk)
  nmap <buffer> [c <Plug>(gita-action-blame-prev-chunk)

  nmap <buffer> : <Plug>(gita-action-blame-command)
endfunction " }}}

function! gita#features#blame#get_pseudo_linenum(linenum) abort  "{{{
  let blamemeta = gita#meta#get('blame#meta')
  let linerefs = blamemeta.linerefs
  if a:linenum > len(linerefs)
    return linerefs[-1]
  elseif a:linenum <= 0
    return linerefs[0]
  else
    return linerefs[a:linenum-1]
  endif
endfunction " }}}
function! gita#features#blame#get_actual_linenum(linenum) abort  "{{{
  let blamemeta = gita#meta#get('blame#meta')
  let lineinfos = blamemeta.lineinfos
  if a:linenum > len(lineinfos)
    let lineinfo = lineinfos[-1]
  elseif a:linenum <= 0
    let lineinfo = lineinfos[0]
  else
    let lineinfo = lineinfos[a:linenum - 1]
  endif
  return lineinfo.linenum.final
endfunction " }}}
function! gita#features#blame#goto(linenum) abort  "{{{
  let pseudo_linenum = gita#features#blame#get_pseudo_linenum(a:linenum)
  keepjumps call setpos('.', [0, pseudo_linenum, 0, 0])
  normal z.
  syncbind
endfunction " }}}
function! gita#features#blame#quit() abort  "{{{
  let partner_bufnr = get(b:, '_gita_blame_partner_bufnr', -1)
  if partner_bufnr == -1
    call gita#utils#prompt#error('gita#feature#blame#quit() required to be called on Gita blame navi or view buffer.')
    return
  endif
  execute printf('%dbdelete', partner_bufnr)
  execute 'bdelete'
endfunction " }}}
function! gita#features#blame#exec(...) abort " {{{
  let gita = gita#get()
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  let options = deepcopy(get(a:000, 0, {}))
  let config  = get(a:000, 1, {})
  if has_key(options, 'file')
    let options['--'] = [
          \ gita#utils#path#unix_abspath(options.file)
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
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  let options = get(a:000, 0, {})
  let config  = get(a:000, 1, {})
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
  let options.file   = gita#utils#eget(options, 'file', '%')
  let options.commit = gita#utils#eget(options, 'commit', 'HEAD')
  let options.commit = options.commit ==# 'WORKTREE' ? '' : options.commit
  let options.porcelain = 1
  let result = gita#features#blame#exec_cached(options, {
        \ 'echo': 'fail',
        \})
  if result.status
    return
  endif
  let blamemeta = s:format_chunks(gita, result.stdout, 50 - 2) " 2 columns for signs
  let abspath = gita#utils#path#unix_abspath(options.file)
  let commit  = options.commit
  call s:view_show(
        \ abspath, commit, blamemeta, extend(deepcopy(options), {
        \  'range':  get(options, 'range'),
        \  'opener': gita#utils#eget(options, 'opener', 'tabedit'),
        \ }),
        \)
  let VIEW_bufnr = bufnr('%')
  call s:navi_show(
        \ abspath, commit, blamemeta, extend(deepcopy(options), {
        \  'range':  get(options, 'range'),
        \  'opener': get(options, 'opener2'),
        \ }),
        \)
  let NAVI_bufnr = bufnr('%')
  " set partner bufnr
  call setbufvar(VIEW_bufnr, '_gita_blame_partner_bufnr', NAVI_bufnr)
  call setbufvar(NAVI_bufnr, '_gita_blame_partner_bufnr', VIEW_bufnr)
  call gita#features#blame#goto(
        \ get(
        \   options, 'line_start',
        \   gita#features#blame#get_actual_linenum(line('.'))
        \ )
        \)
endfunction " }}}
function! gita#features#blame#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let options = extend(
          \ deepcopy(g:gita#features#blame#default_options),
          \ options)
    if !empty(options.__unknown__)
      let options['--'] = options.__unknown__
    endif
    call gita#action#exec('blame', options.__range__, options)
  endif
endfunction " }}}
function! gita#features#blame#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}
function! gita#features#blame#define_highlights() abort " {{{
  highlight default link GitaHorizontal Comment
  highlight default link GitaSummary    Title
  highlight default link GitaMetaInfo   Comment
  highlight default link GitaAuthor     Identifier
  highlight default link GitaTimeDelta  Comment
  highlight default link GitaRevision   String
  highlight default link GitaPrevious   Special
  highlight default link GitaLineNr     LineNr
  highlight default link GitaPseudoSeparator GitaPseudoSeparatorDefault
endfunction " }}}
function! gita#features#blame#define_syntax() abort " {{{
  syntax match GitaSummary   /\v.*/ contains=GitaLineNr,GitaMetaInfo,GitaPrevious
  syntax match GitaLineNr    /\v^\s*[0-9]+/
  syntax match GitaMetaInfo  /\v\w+ authored .*$/ contains=GitaAuthor,GitaTimeDelta,GitaRevision
  syntax match GitaAuthor    /\v\w+\ze authored/ contained
  syntax match GitaTimeDelta /\vauthored \zs.*\ze\s+[0-9a-fA-F]{7}$/ contained
  syntax match GitaRevision  /\v[0-9a-fA-F]{7}$/ contained
  syntax match GitaPrevious  /\vPrev: [0-9a-fA-F]{7}$/ contained
endfunction " }}}
function! gita#features#blame#action(candidates, options, config) abort " {{{
  let candidate = get(a:candidates, 0, {})
  if empty(candidate)
    return
  endif
  call gita#utils#anchor#focus()
  call gita#features#blame#show({
        \ 'file': gita#utils#sget([a:options, candidate], 'path'),
        \ 'commit': gita#utils#sget([a:options, candidate], 'commit'),
        \ 'line_start': gita#utils#sget([a:options, candidate], 'line_start'),
        \ 'line_end': gita#utils#sget([a:options, candidate], 'line_end'),
        \ 'range': get(a:options, 'range', 'tabpage'),
        \})
endfunction " }}}

let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
