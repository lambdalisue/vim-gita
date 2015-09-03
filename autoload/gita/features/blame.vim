let s:save_cpo = &cpo
set cpo&vim

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

let s:navi_actions = {}
function! s:navi_actions.blame_info(candidates, options, config) abort " {{{
  let candidate = get(a:candidates, 0, {})
  if empty(candidate)
    return
  endif
  let formatted_chunk = s:format_chunk(candidate.chunk, 80, 1, s:T.now())
  echo join(formatted_chunk, "\n")
endfunction " }}}
function! s:navi_actions.blame_enter(candidates, options, config) abort " {{{
  let candidate = get(a:candidates, 0, {})
  if empty(candidate)
    return
  endif
  call s:get_history().add()
  call gita#utils#anchor#focus()
  call gita#features#blame#show({
        \ 'file': gita#utils#sget([a:options, candidate], 'path'),
        \ 'commit': gita#utils#sget([a:options, candidate], 'commit'),
        \ 'line_start': gita#utils#sget([a:options, candidate], 'line_start'),
        \ 'line_end': gita#utils#sget([a:options, candidate], 'line_end'),
        \ 'range': get(a:options, 'range', 'tabpage'),
        \})
endfunction " }}}
function! s:navi_actions.blame_history_prev(candidates, options, config) abort " {{{
  call s:get_history().previous()
endfunction " }}}
function! s:navi_actions.blame_history_next(candidates, options, config) abort " {{{
  call s:get_history().next()
endfunction " }}}
function! s:navi_actions.browse(candidates, options, config) abort " {{{
  let options = deepcopy(a:options)
  let options.scheme = 'blame'
  call call('gita#features#browse#action', [a:candidates, options, a:config])
endfunction " }}}

function! s:create_chunks(gita, blameobj) abort " {{{
  let previous_revision = ''
  let chunks = []
  for lineinfo in a:blameobj.lineinfos
    if previous_revision ==# lineinfo.revision
      let chunk = get(chunks, -1)
      call add(chunk.contents, lineinfo.contents)
    else
      let previous_revision = lineinfo.revision
      "let chunk = extend(lineinfo, a:blameobj.revision[previous_revision])
      let chunk = extend(
            \ deepcopy(lineinfo),
            \ a:blameobj.revisions[previous_revision]
            \)
      let chunk.index = len(chunks)
      let chunk.contents = [lineinfo.contents]
      let chunk.filename = a:gita.git.get_absolute_path(chunk.filename)
      call add(chunks, chunk)
    endif
  endfor
  return chunks
endfunction " }}}
function! s:format_timestamp(timestamp, timezone, now) abort " {{{
  let datetime  = s:T.from_unix_time(a:timestamp, a:timezone)
  let timedelta = datetime.delta(a:now)
  if timedelta.duration().months() < 3
    return timedelta.about()
  else
    return 'on ' . datetime.strftime('%d %b, %Y')
  endif
endfunction " }}}
function! s:format_chunk(chunk, width, wrap, now) abort " {{{
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
  let revision = a:chunk.revision[:6]
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
        \   repeat(' ', a:width - 8 - len(author_info)),
        \   revision,
        \ )
        \])
  return formatted
endfunction " }}}
function! s:format_chunks(chunks, width) abort " {{{
  let now   = s:T.now()
  let cache = s:C.new()
  let min_chunk_lines = g:gita#features#blame#enable_pseudo_separator ? 2 : 1
  let NAVI = []
  let VIEW = []
  let lineinfos = []
  let linerefs = []
  let separators = []
  let linenum = 1
  for chunk in a:chunks
    " get or create a formatted chunk
    let n_contents  = len(chunk.contents)
    let is_wrapable = n_contents > 2
    let cache_name  = printf('%s%d', chunk.revision, is_wrapable)
    if !cache.has(cache_name)
      let formatted_chunk = s:format_chunk(chunk, a:width, is_wrapable, now)
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
      call add(NAVI, get(formatted_chunk, i, ''))
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
        \ 'chunks': a:chunks,
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
  let w:_gita_blame_history = get(w:, '_gita_blame_history', gita#utils#history#new())
  return w:_gita_blame_history
endfunction " }}}

function! s:view_show(abspath, commit, blamemeta, ...) abort " {{{
  let options = get(a:000, 0, {})
  let gita = gita#get(a:abspath)
  let relpath = gita.git.get_relative_path(a:abspath)
  let bufname = gita#utils#buffer#bufname('BLAME', a:commit, relpath)
  silent call gita#utils#buffer#open(bufname, {
        \ 'group': 'blame_view',
        \ 'range': gita#utils#eget(options, 'range', 'tabpage'),
        \ 'opener': gita#utils#eget(options, 'opener', 'rightbelow vsplit'),
        \})
  setlocal buftype=nofile noswapfile nobuflisted
  setlocal nomodifiable
  setlocal nowrap nofoldenable foldcolumn=0
  setlocal scrollbind scrollopt=ver
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
  augroup vim-gita-blame-view
    autocmd! * <buffer>
    autocmd BufWinEnter <buffer> call s:view_ac_BufWinEnter()
  augroup END
  doautocmd BufReadPost
endfunction " }}}
function! s:view_define_mappings() abort " {{{
endfunction " }}}
function! s:view_define_default_mappings() abort " {{{
endfunction " }}}
function! s:view_ac_BufWinEnter() abort " {{{
  let abspath   = gita#meta#get('filename')
  let commit    = gita#meta#get('commit')
  let blamemeta = gita#meta#get('blame#meta')
  try
    let saved_eventignore = &eventignore
    set eventignore=BufWinEnter
    call s:navi_show(abspath, commit, blamemeta)
  finally
    let &eventignore = saved_eventignore
  endtry
  keepjumps wincmd p
  call gita#features#blame#goto(gita#features#blame#get_actual_linenum(line('.')))
endfunction " }}}
function! s:navi_get_candidates(start, end, ...) abort " {{{
  let commit = gita#meta#get('commit')
  let blamemeta = gita#meta#get('blame#meta')
  let lineinfo = blamemeta.lineinfos[a:start]
  let chunk = blamemeta.chunks[lineinfo.chunkref]
  let candidate = gita#action#new_candidate(chunk.filename, chunk.revision, {
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
  let bufname = gita#utils#buffer#bufname('BLAME', 'NAVI', a:commit, relpath)
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
  augroup vim-gita-blame-navi
    autocmd! * <buffer>
    autocmd BufWinEnter <buffer> call s:view_ac_BufWinEnter()
  augroup END
endfunction " }}}
function! s:navi_define_mappings() abort " {{{
  call gita#monitor#define_mappings()
  unmap <buffer> <Plug>(gita-action-help-s)

  nnoremap <silent><buffer> <Plug>(gita-action-blame-info)
        \ :<C-u>call gita#action#call('blame_info')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-blame-enter)
        \ :<C-u>call gita#action#call('blame_enter')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-blame-history-prev)
        \ :<C-u>call gita#action#call('blame_history_prev')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-blame-history-next)
        \ :<C-u>call gita#action#call('blame_history_next')<CR>
endfunction " }}}
function! s:navi_define_default_mappings() abort " {{{
  call gita#monitor#define_default_mappings()
  unmap <buffer> ?s

  nmap <buffer> g<C-g> <Plug>(gita-action-blame-info)
  nmap <buffer> <CR> <Plug>(gita-action-blame-enter)
  nmap <buffer> <C-p> <Plug>(gita-action-blame-history-prev)
  nmap <buffer> <C-n> <Plug>(gita-action-blame-history-next)
endfunction " }}}
function! s:navi_ac_BufWinEnter() abort " {{{
  let abspath   = gita#meta#get('filename')
  let commit    = gita#meta#get('commit')
  let blamemeta = gita#meta#get('blame#meta')
  try
    let saved_eventignore = &eventignore
    set eventignore=BufWinEnter
    call s:view_show(abspath, commit, blamemeta)
  finally
    let &eventignore = saved_eventignore
  endtry
  keepjumps wincmd p
  call gita#features#blame#goto(gita#features#blame#get_actual_linenum(line('.')))
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
function! gita#features#blame#exec(...) abort " {{{
  let gita = gita#get()
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  let options = deepcopy(get(a:000, 0, {}))
  let config  = get(a:000, 1, {})
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
  let options.porcelain = 1
  let result = gita#features#blame#exec_cached(options, {
        \ 'echo': 'fail',
        \})
  if result.status
    return
  endif
  let blameobj = s:B.parse(result.stdout, { 'fail_silently': !g:gita#debug })
  let chunks = s:create_chunks(gita, blameobj)
  let blamemeta = s:format_chunks(chunks, 50 - 3) " 3 columns for signs
  let abspath = gita#utils#ensure_abspath(gita#utils#expand(options.file))
  let commit  = options.commit
  try
    let saved_eventignore = &eventignore
    set eventignore=BufWinEnter
    call s:view_show(
          \ abspath, commit, blamemeta, extend(deepcopy(options), {
          \  'range':  get(options, 'range'),
          \  'opener': gita#utils#eget(options, 'opener', 'tabedit'),
          \ }),
          \)
    call s:navi_show(
          \ abspath, commit, blamemeta, extend(deepcopy(options), {
          \  'range':  get(options, 'range'),
          \  'opener': get(options, 'opener2'),
          \ }),
          \)
  finally
    let &eventignore = saved_eventignore
  endtry
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
  highlight default link GitaPseudoSeparator GitaPseudoSeparatorDefault
endfunction " }}}
function! gita#features#blame#define_syntax() abort " {{{
  syntax match GitaSummary   /.*/
  syntax match GitaMetaInfo  /\v^.*\sauthored\s.*$/ contains=GitaAuthor,GitaTimeDelta,GitaRevision
  syntax match GitaAuthor    /\v^.*\ze\sauthored/ contained
  syntax match GitaTimeDelta /\vauthored\s\zs.*\ze\s+[0-9a-fA-F]{8}$/ contained
  syntax match GitaRevision  /\v[0-9a-fA-F]{8}$/ contained
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

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
