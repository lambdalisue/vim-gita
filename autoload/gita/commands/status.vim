let s:save_cpo = &cpo
set cpo&vim

let s:const = {}
let s:const.bufname = has('unix') ? 'gita:status' : 'gita_status'
let s:const.filetype = 'gita-status'


" Modules
let s:P = gita#utils#import('Prelude')
let s:L = gita#utils#import('Data.List')
let s:F = gita#utils#import('System.File')
let s:A = gita#utils#import('ArgumentParser')


" Private functions
function! s:get_gita(...) abort " {{{
  let gita = call('gita#core#get', a:000)
  let gita.features = get(gita, 'features', {})
  let gita.features.status = get(gita.features, 'status', {})
  return gita
endfunction " }}}
function! s:smart_map(...) abort " {{{
  return call('gita#utils#status#smart_map', a:000)
endfunction " }}}
function! s:filter_statuses(statuses, options, validate) abort " {{{
  let statuses = gita#utils#ensure_list(a:statuses)
  let options = deepcopy(a:options)
  let valid_statuses = []
  for status in statuses
    if a:validate(status, options)
      continue
    endif
    call add(valid_statuses, status)
  endfor
  if empty(valid_statuses)
    if !get(options, 'ignore_empty_warning', 0)
      call gita#utils#warn(
            \ 'No valid statuses were specified.',
            \)
    endif
  endif
  return valid_statuses
endfunction " }}}

function! s:open(...) abort " {{{
  let options = extend(
        \ get(b:, '_options', {}),
        \ get(a:000, 0, {}),
        \)
  let gita = s:get_gita()
  let invoker = gita#utils#invoker#get()

  if !gita.enabled
    redraw | call gita#utils#info(printf(
          \ 'Git is not available in the current buffer "%s".',
          \ bufname('%'),
          \))
    return -1
  endif

  let ret = gita#utils#buffer#open(s:const.bufname, 'support_window', {
        \ 'opener': 'topleft 15 split',
        \ 'range': 'tabpage',
        \})
  silent execute printf('setlocal filetype=%s', s:const.filetype)

  " update buffer variables
  let b:_gita = gita
  let b:_options = options
  call gita#utils#invoker#set(invoker)
  call invoker.update_winnum()

  " check if construction is required
  if exists('b:_constructed') && !get(g:, 'gita#debug', 0)
    return ret.bufnr
  endif

  " construction
  setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
  setlocal winfixwidth winfixheight
  setlocal cursorline
  setlocal nomodifiable

  autocmd! * <buffer>
  " Note:
  "
  " :wq       : QuitPre > BufWriteCmd > WinLeave > BufWinLeave
  " :q        : QuitPre > WinLeave > BufWinLeave
  " :e        : BufWinLeave
  " :wincmd w : WinLeave
  "
  " s:ac_quit need to be called after BufWriteCmd and only when closing a
  " buffre window (not when :e, :wincmd w).
  " That's why the following autocmd combination is required.
  autocmd WinEnter    <buffer> let b:_winleave = 0
  autocmd WinLeave    <buffer> let b:_winleave = 1
  autocmd BufWinEnter <buffer> let b:_winleave = 0
  autocmd BufWinLeave <buffer> if get(b:, '_winleave', 0) | call s:ac_quit() | endif

  call s:defmap()
  call s:update(options)
  let b:_constructed = 1
  return ret.bufnr
endfunction " }}}
function! s:update(...) abort " {{{
  let options = extend(
        \ get(b:, '_options', {}),
        \ get(a:000, 0, {}),
        \)
  let gita = s:get_gita()

  let result = gita.git.get_parsed_status(extend({
        \ 'no_cache': 1,
        \}, options))
  if get(result, 'status', 0)
    redraw
    call gita#utils#errormsg(
          \ printf('vim-gita: Fail: %s', join(result.args)),
          \)
    call gita#utils#infomsg(
          \ result.stdout,
          \)
    return -1
  endif

  " create statuses lines & map
  let statuses_map = {}
  let statuses_lines = []
  for status in result.all
    call add(statuses_lines, status.record)
    let statuses_map[status.record] = status
  endfor
  call gita#utils#status#set_statuses_map(statuses_map)

  " create buffer lines
  let buflines = s:L.flatten([
        \ ['# Press ?m and/or ?s to toggle a help of mapping and/or short format.'],
        \ gita#utils#help#get('status_mapping'),
        \ gita#utils#help#get('short_format'),
        \ gita#utils#status#get_status_header(),
        \ statuses_lines,
        \ empty(statuses_map) ? ['Nothing to commit (Working tree is clean).'] : [],
        \])

  " update content
  call gita#utils#buffer#update(buflines)
endfunction " }}}
function! s:defmap() abort " {{{
  noremap <silent><buffer> <Plug>(gita-action-help-m)   :call <SID>action('help', { 'name': 'status_mapping' })
  noremap <silent><buffer> <Plug>(gita-action-help-s)   :call <SID>action('help', { 'name': 'short_format' })

  noremap <silent><buffer> <Plug>(gita-action-update)   :call <SID>action('update')<CR>
  noremap <silent><buffer> <Plug>(gita-action-switch)   :call <SID>action('open_commit')<CR>
  noremap <silent><buffer> <Plug>(gita-action-commit)   :call <SID>action('open_commit', { 'new': 1, 'amend': 0 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-commit-a) :call <SID>action('open_commit', { 'new': 1, 'amend': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-open)     :call <SID>action('open', { 'opener': 'edit' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-open-h)   :call <SID>action('open', { 'opener': 'botright split' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-open-v)   :call <SID>action('open', { 'opener': 'botright vsplit' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-diff)     :call <SID>action('diff_open', { 'opener': 'edit' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-diff-h)   :call <SID>action('diff_compare', { 'vertical': 0 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-diff-v)   :call <SID>action('diff_compare', { 'vertical': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-solve2-h) :call <SID>action('solve2', { 'vertical': 0 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-solve2-v) :call <SID>action('solve2', { 'vertical': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-solve3-h) :call <SID>action('solve3', { 'vertical': 0 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-solve3-v) :call <SID>action('solve3', { 'vertical': 1 })<CR>

  noremap <silent><buffer> <Plug>(gita-action-add)      :call <SID>action('add')<CR>
  noremap <silent><buffer> <Plug>(gita-action-ADD)      :call <SID>action('add', { 'force': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-rm)       :call <SID>action('rm')<CR>
  noremap <silent><buffer> <Plug>(gita-action-RM)       :call <SID>action('RM', { 'force': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-reset)    :call <SID>action('reset')<CR>
  noremap <silent><buffer> <Plug>(gita-action-checkout) :call <SID>action('checkout')<CR>
  noremap <silent><buffer> <Plug>(gita-action-CHECKOUT) :call <SID>action('checkout', { 'force': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-ours)     :call <SID>action('ours')<CR>
  noremap <silent><buffer> <Plug>(gita-action-theirs)   :call <SID>action('theirs')<CR>
  noremap <silent><buffer> <Plug>(gita-action-stage)    :call <SID>action('stage')<CR>
  noremap <silent><buffer> <Plug>(gita-action-unstage)  :call <SID>action('unstage')<CR>
  noremap <silent><buffer> <Plug>(gita-action-toggle)   :call <SID>action('toggle')<CR>
  noremap <silent><buffer> <Plug>(gita-action-discard)  :call <SID>action('discard')<CR>

  if get(g:, 'gita#commands#status#enable_default_keymap', 1)
    nmap <buffer><silent> q  :<C-u>quit<CR>
    nmap <buffer> <C-l> <Plug>(gita-action-update)

    nmap <buffer> ?m <Plug>(gita-action-help-m)
    nmap <buffer> ?s <Plug>(gita-action-help-s)

    nmap <buffer> cc <Plug>(gita-action-switch)
    nmap <buffer> cC <Plug>(gita-action-commit)
    nmap <buffer> cA <Plug>(gita-action-commit-a)

    nmap <buffer><expr> e  <SID>smart_map('e', '<Plug>(gita-action-open)')
    nmap <buffer><expr> E  <SID>smart_map('E', '<Plug>(gita-action-open-v)')
    nmap <buffer><expr> d  <SID>smart_map('d', '<Plug>(gita-action-diff)')
    nmap <buffer><expr> D  <SID>smart_map('D', '<Plug>(gita-action-diff-v)')
    nmap <buffer><expr> s  <SID>smart_map('s', '<Plug>(gita-action-solve2-v)')
    nmap <buffer><expr> S  <SID>smart_map('S', '<Plug>(gita-action-solve3-v)')

    " operation
    nmap <buffer><expr> << <SID>smart_map('<<', '<Plug>(gita-action-stage)')
    nmap <buffer><expr> >> <SID>smart_map('>>', '<Plug>(gita-action-unstage)')
    nmap <buffer><expr> -- <SID>smart_map('--', '<Plug>(gita-action-toggle)')
    nmap <buffer><expr> == <SID>smart_map('==', '<Plug>(gita-action-discard)')

    " raw operation
    nmap <buffer><expr> -a <SID>smart_map('-a', '<Plug>(gita-action-add)')
    nmap <buffer><expr> -A <SID>smart_map('-A', '<Plug>(gita-action-ADD)')
    nmap <buffer><expr> -r <SID>smart_map('-r', '<Plug>(gita-action-reset)')
    nmap <buffer><expr> -d <SID>smart_map('-d', '<Plug>(gita-action-rm)')
    nmap <buffer><expr> -D <SID>smart_map('-D', '<Plug>(gita-action-RM)')
    nmap <buffer><expr> -c <SID>smart_map('-c', '<Plug>(gita-action-checkout)')
    nmap <buffer><expr> -C <SID>smart_map('-C', '<Plug>(gita-action-CHECKOUT)')
    nmap <buffer><expr> -o <SID>smart_map('-o', '<Plug>(gita-action-ours)')
    nmap <buffer><expr> -t <SID>smart_map('-t', '<Plug>(gita-action-theirs)')

    vmap <buffer> << <Plug>(gita-action-stage)
    vmap <buffer> >> <Plug>(gita-action-unstage)
    vmap <buffer> -- <Plug>(gita-action-toggle)
    vmap <buffer> == <Plug>(gita-action-discard)

    vmap <buffer> -a <Plug>(gita-action-add)
    vmap <buffer> -A <Plug>(gita-action-ADD)
    vmap <buffer> -r <Plug>(gita-action-reset)
    vmap <buffer> -d <Plug>(gita-action-rm)
    vmap <buffer> -D <Plug>(gita-action-RM)
    vmap <buffer> -c <Plug>(gita-action-checkout)
    vmap <buffer> -C <Plug>(gita-action-CHECKOUT)
    vmap <buffer> -o <Plug>(gita-action-ours)
    vmap <buffer> -t <Plug>(gita-action-theirs)
  endif
endfunction " }}}
function! s:ac_quit() abort " {{{
  let invoker = gita#utils#invoker#get()
  call invoker.focus()
  call gita#utils#invoker#clear()
endfunction " }}}

function! s:validate_add(status, options) abort " {{{
  if a:status.is_unstaged || a:status.is_untracked
    return 0
  elseif a:status.is_ignored && get(a:options, 'force', 0)
    return 0
  elseif a:status.is_ignored
    call gita#utils#warn(printf(
          \ 'An ignored file "%s" cannot be added. Use <Plug>(gita-action-ADD) instead.',
          \ a:status.path,
          \))
    return 1
  elseif a:status.is_conflicted
    if a:status.sign ==# 'DD'
      call gita#utils#warn(printf(
            \ 'A both deleted conflict file "%s" cannot be added. Use <Plug>(gita-action-rm) instead.',
            \ a:status.path,
            \))
      return 1
    else
      return 0
    endif
  else
    call gita#utils#warn(printf(
          \ 'No changes of "%s" exist on working tree.',
          \ a:status.path,
          \))
    return 1
  endif
endfunction " }}}
function! s:validate_rm(status, options) abort " {{{
  if (a:status.is_staged || a:status.is_unstaged) && a:status.worktree ==# 'D'
    " the file is already removed from filesystem thus it should be able to
    " remove from index without a warning
    return 0
  elseif a:status.is_staged || a:status.is_unstaged
    if get(a:options, 'force', 0)
      return 0
    else
      call gita#utils#warn(printf(
            \ 'A file "%s" has changes and cannot be deleted. Use <Plug>(gita-action-RM) instead.',
            \ a:status.path,
            \))
      return 1
    endif
  elseif a:status.is_untracked || a:status.is_ignored
    call gita#utils#warn(printf(
          \ 'An untracked/ignored file "%s" cannot be deleted.',
          \ a:status.path,
          \))
    return 1
  elseif a:status.is_conflicted
    if a:status.sign ==# 'AU'
      call gita#utils#warn(printf(
            \ 'A added by us conflict file "%s" cannot be deleted. Use <Plug>(git-action-add) instead.',
            \ a:status.path,
            \))
      return 1
    elseif a:status.sign ==# 'UA'
      call gita#utils#warn(printf(
            \ 'A added by them conflict file "%s" cannot be deleted. Use <Plug>(git-action-add) instead.',
            \ a:status.path,
            \))
      return 1
    elseif a:status.sign ==# 'AA'
      call gita#utils#warn(printf(
            \ 'A both added conflict file "%s" cannot be deleted. Use <Plug>(git-action-add) instead.',
            \ a:status.path,
            \))
      return 1
    elseif a:status.sign ==# 'UU'
      call gita#utils#warn(printf(
            \ 'A both modified conflict file "%s" cannot be deleted. Use <Plug>(git-action-add) instead.',
            \ a:status.path,
            \))
      return 1
    else
      return 0
    endif
  else
    " it should not be called
    call gita#utils#errormsg(printf(
          \ 'An unexpected pattern "%s" is called for "rm".',
          \ a:status.sign,
          \))
    call gita#utils#open_gita_issue()
    return 1
  endif
endfunction " }}}
function! s:validate_reset(status, options) abort " {{{
  if a:status.is_staged
    return 0
  elseif a:status.is_untracked || a:status.is_ignored
    call gita#utils#warn(printf(
          \ 'An untracked/ignored file "%s" cannot be reset.',
          \ a:status.path,
          \))
    return 1
  elseif a:status.is_conflicted
    call gita#utils#warn(printf(
          \ 'A conflicted file "%s" cannot be reset. ',
          \ a:status.path,
          \))
    return 1
  else
    call gita#utils#warn(printf(
          \ 'No changes of "%s" exist on index.',
          \ a:status.path,
          \))
    return 1
  endif
endfunction " }}}
function! s:validate_checkout(status, options) abort " {{{
  if a:status.is_unstaged
    if get(a:options, 'force', 0)
      return 0
    else
      call gita#utils#warn(printf(
            \ 'A file "%s" has unstaged changes. Use <Plug>(gita-action-CHECKOUT) instead.',
            \ a:status.path,
            \))
      return 1
    endif
  elseif a:status.is_untracked || a:status.is_ignored
    call gita#utils#warn(printf(
          \ 'An untracked/ignored file "%s" cannot be checked out.',
          \ a:status.path,
          \))
    return 1
  elseif a:status.is_conflicted
    call gita#utils#warn(printf(
          \ 'A conflicted file "%s" cannot be checked out. Use <Plug>(gita-action-ours) or <Plug>(gita-action-theirs) instead.',
          \ a:status.path,
          \))
    return 1
  else
    return 0
  endif
endfunction " }}}
function! s:validate_checkout_ours(status, options) abort " {{{
  if !a:status.is_conflicted
    call gita#utils#warn(printf(
          \ 'No ours version of a non conflicted file "%s" is available. Use <Plug>(gita-action-checkout) instead.',
          \ a:status.path,
          \))
    return 1
  else
    if a:status.sign ==# 'DD'
      call gita#utils#warn(printf(
            \ 'No ours version of a both deleted conflict file "%s" is available. Use <Plug>(gita-action-rm) instead.',
            \ a:status.path,
            \))
      return 1
    elseif a:status.sign ==# 'DU'
      call gita#utils#warn(printf(
            \ 'No ours version of a deleted by us conflict file "%s" is available. Use <Plug>(gita-action-add) or <Plug>(gita-action-rm) instead.',
            \ a:status.path,
            \))
      return 1
    else
      return 0
    endif
  endif
endfunction " }}}
function! s:validate_checkout_theirs(status, options) abort " {{{
  if !a:status.is_conflicted
    call gita#utils#warn(printf(
          \ 'No theirs version of a non conflicted file "%s" is available. Use <Plug>(gita-action-checkout) instead.',
          \ a:status.path,
          \))
    return 1
  else
    if a:status.sign ==# 'DD'
      call gita#utils#warn(printf(
            \ 'No theirs version of a both deleted conflict file "%s" is available. Use <Plug>(gita-action-rm) instead.',
            \ a:status.path,
            \))
      return 1
    elseif a:status.sign ==# 'UD'
      call gita#utils#warn(printf(
            \ 'No theirs version of a deleted by them conflict file "%s" is available. Use <Plug>(gita-action-add) or <Plug>(gita-action-rm) instead.',
            \ a:status.path,
            \))
      return 1
    else
      return 0
    endif
  endif
endfunction " }}}

function! s:action(name, ...) range abort " {{{
  let options  = extend(deepcopy(b:_options), get(a:000, 0, {}))
  let statuses = gita#utils#status#get_selected_statuses(a:firstline, a:lastline)
  let args = [statuses, options]
  call call(printf('s:action_%s', a:name), args)
  call s:update()
endfunction " }}}
function! s:action_update(statuses, options) abort " {{{
  call s:update()
endfunction " }}}
function! s:action_open(statuses, options) abort " {{{
  call gita#utils#status#action_open(a:statuses, a:options)
endfunction " }}}
function! s:action_help(statuses, options) abort " {{{
  call gita#utils#status#help(a:statuses, a:options)
endfunction " }}}
function! s:action_add(statuses, options) abort " {{{
  let statuses = s:filter_statuses(
        \ a:statuses,
        \ a:options,
        \ function('s:validate_add'),
        \)
  let options = deepcopy(a:options)
  if empty(a:statuses)
    return
  endif
  let gita = s:get_gita()
  let files = map(statuses, 'gita.git.get_absolute_path(v:val.path)')
  let result = gita.git.add(options, files)
  if result.status
    call gita#utils#errormsg(printf(
          \ 'vim-gita: Fail: %s', join(result.args)
          \))
    call gita#utils#infomsg(result.stdout)
  else
    call gita#utils#doautocmd('add-post')
  endif
endfunction " }}}
function! s:action_rm(statuses, options) abort " {{{
  let statuses = s:filter_statuses(
        \ a:statuses,
        \ a:options,
        \ function('s:validate_rm'),
        \)
  let options = deepcopy(a:options)
  if empty(a:statuses)
    return
  endif
  let gita = s:get_gita()
  let files = map(statuses, 'gita.git.get_absolute_path(v:val.path)')
  let result = gita.git.rm(options, files)
  if result.status
    call gita#utils#errormsg(printf(
          \ 'vim-gita: Fail: %s', join(result.args)
          \))
    call gita#utils#infomsg(result.stdout)
  else
    call gita#utils#doautocmd('rm-post')
  endif
endfunction " }}}
function! s:action_reset(statuses, options) abort " {{{
  let statuses = s:filter_statuses(
        \ a:statuses,
        \ a:options,
        \ function('s:validate_reset'),
        \)
  let options = deepcopy(a:options)
  if empty(a:statuses)
    return
  endif
  let gita = s:get_gita()
  let files = map(statuses, 'gita.git.get_absolute_path(v:val.path)')
  let result = gita.git.reset(options, '', files)
  if result.status
    call gita#utils#errormsg(printf(
          \ 'vim-gita: Fail: %s', join(result.args)
          \))
    call gita#utils#infomsg(result.stdout)
  else
    call gita#utils#doautocmd('reset-post')
  endif
endfunction " }}}
function! s:action_checkout(statuses, options) abort " {{{
  let statuses = s:filter_statuses(
        \ a:statuses,
        \ a:options,
        \ function('s:validate_checkout'),
        \)
  let options = deepcopy(a:options)
  if empty(a:statuses)
    return
  endif

  let target = get(options, 'target', '')
  if empty(target)
    let target = gita#utils#ask('Checkout from: ', 'INDEX')
    if empty(target)
      redraw
      call gita#utils#info('The operation has canceled by user.')
      return
    endif
  endif
  let target = target ==# 'INDEX' ? '' : target

  let gita = s:get_gita()
  let files = map(statuses, 'gita.git.get_absolute_path(v:val.path)')
  let result = gita.git.checkout(options, target, files)
  if result.status
    call gita#utils#errormsg(printf(
          \ 'vim-gita: Fail: %s', join(result.args)
          \))
    call gita#utils#infomsg(result.stdout)
  else
    call gita#utils#doautocmd('checkout-post')
  endif
endfunction " }}}
function! s:action_checkout_ours(statuses, options) abort " {{{
  let statuses = s:filter_statuses(
        \ a:statuses,
        \ a:options,
        \ function('s:validate_checkout_ours'),
        \)
  let options = deepcopy(a:options)
  let options.ours = 1
  if empty(a:statuses)
    return
  endif

  let gita = s:get_gita()
  let files = map(statuses, 'gita.git.get_absolute_path(v:val.path)')
  let result = gita.git.checkout(options, '', files)
  if result.status
    call gita#utils#errormsg(printf(
          \ 'vim-gita: Fail: %s', join(result.args)
          \))
    call gita#utils#infomsg(result.stdout)
  else
    call gita#utils#doautocmd('checkout-post')
  endif
endfunction " }}}
function! s:action_checkout_theirs(statuses, options) abort " {{{
  let statuses = s:filter_statuses(
        \ a:statuses,
        \ a:options,
        \ function('s:validate_checkout_theirs'),
        \)
  let options = deepcopy(a:options)
  let options.theirs = 1
  if empty(a:statuses)
    return
  endif

  let gita = s:get_gita()
  let files = map(statuses, 'gita.git.get_absolute_path(v:val.path)')
  let result = gita.git.checkout(options, '', files)
  if result.status
    call gita#utils#errormsg(printf(
          \ 'vim-gita: Fail: %s', join(result.args)
          \))
    call gita#utils#infomsg(result.stdout)
  else
    call gita#utils#doautocmd('checkout-post')
  endif
endfunction " }}}
function! s:action_stage(statuses, options) abort " {{{
  let statuses = gita#utils#ensure_list(a:statuses)
  let options = deepcopy(a:options)
  let add_statuses = []
  let rm_statuses = []
  for status in statuses
    if status.is_conflicted
      call gita#utils#warn(printf(
            \ 'A conflicted file "%s" cannot be staged. Use <Plug>(gita-action-add) or <Plug>(gita-action-rm) directly.',
            \ status.path,
            \))
      continue
    elseif status.is_unstaged && status.worktree ==# 'D'
      call add(rm_statuses, status)
    else
      if s:validate_add(status, options)
        continue
      endif
      call add(add_statuses, status)
    endif
  endfor
  if empty(add_statuses) && empty(rm_statuses)
    if !get(options, 'ignore_empty_warning', 0)
      call gita#utils#warn(
            \ 'No valid statuses were specified.',
            \)
    endif
    return
  endif
  let options.ignore_empty_warning = 1
  call s:action_add(add_statuses, options)
  call s:action_rm(rm_statuses, options)
endfunction " }}}
function! s:action_unstage(statuses, options) abort " {{{
  " this is a just alias of 's:action_reset'
  call s:action_reset(a:statuses, a:options)
endfunction " }}}
function! s:action_toggle(statuses, options) abort " {{{
  let statuses = gita#utils#ensure_list(a:statuses)
  let options = deepcopy(a:options)
  let stage_statuses = []
  let reset_statuses = []
  for status in statuses
    if status.is_conflicted
      call gita#utils#warn(printf(
            \ 'A conflicted file "%s" cannot be staged/unstaged. Use <Plug>(gita-action-add) or <Plug>(gita-action-rm) directly.',
            \ status.path,
            \))
      continue
    elseif status.is_staged && status.is_unstaged
      if get(g:, 'gita#features#status_buffer#toggle_prefer_unstage', 0)
        call add(reset_statuses, status)
      else
        call add(stage_statuses, status)
      endif
    elseif status.is_staged
      call add(reset_statuses, status)
    elseif status.is_unstaged || status.is_untracked || status.is_ignored
      call add(stage_statuses, status)
    else
      " it should not be called
      call gita#utils#errormsg(printf(
            \ 'An unexpected pattern "%s" is called for "toggle".',
            \ status.sign,
            \))
      call gita#utils#open_gita_issue()
    endif
  endfor
  if empty(stage_statuses) && empty(reset_statuses)
    if !get(options, 'ignore_empty_warning', 0)
      call gita#utils#warn(
            \ 'No valid statuses were specified.',
            \)
    endif
    return
  endif
  let options.ignore_empty_warning = 1
  call s:action_stage(stage_statuses, options)
  call s:action_reset(reset_statuses, options)
endfunction " }}}
function! s:action_discard(statuses, options) abort " {{{
  let statuses = gita#utils#ensure_list(a:statuses)
  let options = deepcopy(a:options)
  let delete_statuses = []
  let checkout_statuses = []
  for status in statuses
    if status.is_conflicted
      call gita#utils#warn(printf(
            \ 'A conflicted file "%s" cannot be discarded. Resolve the conflict first.',
            \ status.path,
            \))
      continue
    elseif status.is_untracked || status.is_ignored
      call add(delete_statuses, status)
    elseif status.is_staged || status.is_unstaged
      call add(checkout_statuses, status)
    else
      " it should not be called
      call gita#utils#errormsg(printf(
            \ 'An unexpected pattern "%s" is called for "discard".',
            \ status.sign,
            \))
      call gita#utils#open_gita_issue()
    endif
  endfor
  if empty(delete_statuses) && empty(checkout_statuses)
    if !get(options, 'ignore_empty_warning', 0)
      call gita#utils#warn(
            \ 'No valid statuses were specified.',
            \)
    endif
    return
  endif
  if get(options, 'confirm', 1)
    call gita#utils#warn(join([
          \ 'A discard action will discard all local changes on the working tree',
          \ 'and the operation is irreversible, mean that you have no chance to',
          \ 'revert the operation.',
          \]))
    if !gita#utils#asktf('Are you sure you want to discard the changes?')
      call gita#utils#info(
            \ 'The operation has canceled by user.'
            \)
      return
    endif
  endif
  " delete untracked files
  for status in delete_statuses
    let path = get(status, 'path2', get(status, 'path', ''))
    if isdirectory(path)
      silent! call s:F.rmdir(path, 'r')
    elseif filewritable(path)
      silent! call delete(path)
    endif
  endfor
  " checkout tracked files from HEAD
  let options.ignore_empty_warning = 1
  let options.commit = 'INDEX'
  let options.force = 1
  call s:action_checkout(checkout_statuses, options)
endfunction " }}}

function! s:get_parser() abort " {{{
  if !exists('s:parser') || get(g:, 'gita#debug', 0)
    let s:parser = s:A.new({
          \ 'name': 'Gita status',
          \ 'description': 'show the working tree status in Gita interface',
          \})
    let t = s:A.types
    call s:parser.add_argument(
          \ '--untracked-files', '-u',
          \ 'show untracked files, optional modes: all, normal, no. (Default: all)', {
          \   'choices': ['all', 'normal', 'no'],
          \   'default': 'all',
          \ })
    call s:parser.add_argument(
          \ '--ignored',
          \ 'show ignored files',
          \)
    call s:parser.add_argument(
          \ '--ignore-submodules',
          \ 'ignore changes to submodules, optional when: all, dirty, untracked (Default: all)', {
          \   'choices': ['all', 'dirty', 'untracked'],
          \   'default': 'all',
          \})
  endif
  return s:parser
endfunction " }}}
function! s:parse(...) abort " {{{
  let parser = s:get_parser()
  return call(parser.parse, a:000, parser)
endfunction " }}}


" Public function
function! gita#commands#status#open(...) abort " {{{
  call call('s:open', a:000)
endfunction " }}}
function! gita#commands#status#update(...) abort " {{{
  call call('s:update', a:000)
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
