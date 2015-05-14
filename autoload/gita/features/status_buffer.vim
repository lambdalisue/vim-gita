let s:save_cpo = &cpo
set cpo&vim

let s:const = {}
let s:const.bufname = has('unix') ? 'gita:status' : 'gita_status'
let s:const.filetype = 'gita-status'

let s:P = gita#utils#import('Prelude')
let s:L = gita#utils#import('Data.List')
let s:F = gita#utils#import('System.File')

function! s:get_gita(...) abort " {{{
  let gita = call('gita#core#get', a:000)
  let gita.features = get(gita, 'features', {})
  let gita.features.status = get(gita.features, 'status', {})
  return gita
endfunction " }}}
function! s:smart_map(lhs, rhs) abort " {{{
  return empty(s:get_selected_status()) ? a:lhs : a:rhs
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

  let b:_gita = gita
  let b:_options = options

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
  "autocmd WinEnter    <buffer> let b:_winleave = 0
  "autocmd WinLeave    <buffer> let b:_winleave = 1
  "autocmd BufWinEnter <buffer> let b:_winleave = 0
  "autocmd BufWinLeave <buffer> if get(b:, '_winleave', 0) | call s:ac_quit() | endif

  "call s:defmap()
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

function! s:validate_add(status, options) abort " {{{
  if get(a:status, 'is_virtual', 0)
    " virtual status cannot be validated thus just pass the validation
    " so that 'git' can validate.
    return 0
  elseif a:status.is_unstaged || a:status.is_untracked
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
  if get(a:status, 'is_virtual', 0)
    " virtual status cannot be validated thus just pass the validation
    " so that 'git' can validate.
    return 0
  elseif (a:status.is_staged || a:status.is_unstaged) && a:status.worktree ==# 'D'
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
  if get(a:status, 'is_virtual', 0)
    " virtual status cannot be validated thus just pass the validation
    " so that 'git' can validate.
    return 0
  elseif a:status.is_staged
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
  if get(a:status, 'is_virtual', 0)
    " virtual status cannot be validated thus just pass the validation
    " so that 'git' can validate.
    return 0
  elseif a:status.is_unstaged
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

function! s:action(name, ...) abort " {{{
  let multiple = get(a:000, 0, 0)
  let options  = get(a:000, 1, {})
  if s:P.is_dict(multiple)
    let options = multiple
    unlet! multiple | let multiple = 0
  endif
  let options = extend(deepcopy(b:_options), options)

  if multiple
    let statuses = gita#utils#status#get_selected_statuses()
    let args = [statuses, options]
  else
    let status = gita#utils#status#get_selected_status()
    let args = [status, options]
  endif

  call call(printf('s:action_%s', a:name), args)
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
    call gita#utils#doaotocmd('add-post')
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
    call gita#utils#doaotocmd('rm-post')
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
    call gita#utils#doaotocmd('reset-post')
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
    call gita#utils#doaotocmd('checkout-post')
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
    call gita#utils#doaotocmd('checkout-post')
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
    call gita#utils#doaotocmd('checkout-post')
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

function! gita#features#status_buffer#open(...) abort " {{{
  call call('s:open', a:000)
endfunction " }}}
function! gita#features#status_buffer#update(...) abort " {{{
  call call('s:update', a:000)
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
