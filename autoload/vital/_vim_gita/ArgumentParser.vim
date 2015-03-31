"******************************************************************************
" High functional argument (option) parser
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

function! s:_vital_loaded(V)
  let s:List = a:V.import('Data.List')
endfunction

function! s:_vital_depends()
  return ['Data.List']
endfunction

" Reference functions
function! s:_T() " {{{
  return 1
endfunction " }}}
function! s:_F() " {{{
  return 0
endfunction " }}}
function! s:_true() " {{{
  return function('s:_T')
endfunction " }}}
function! s:_false() " {{{
  return function('s:_F')
endfunction " }}}
function! s:_any() " {{{
  return "ANY"
endfunction " }}}
function! s:_switch() " {{{
  return "SWITCH"
endfunction " }}}
function! s:_value() " {{{
  return "VALUE"
endfunction " }}}
function! s:_choice() " {{{
  return "CHOICE"
endfunction " }}}

" Private functions
function! s:_listalize(value) abort " {{{
  if type(a:value) == 3
    return a:value
  endif
  return [a:value]
endfunction " }}}
function! s:shellwords(str) abort " {{{
  let sd = '\([^ \t''"]\+\)'        " Space/Tab separated texts
  let sq = '''\zs\([^'']\+\)\ze'''  " Single quotation wrapped text
  let dq = '"\zs\([^"]\+\)\ze"'     " Double quotation wrapped text
  let pattern = printf('\%%(%s\|%s\|%s\)', sq, dq, sd)
  " Split texts by spaces between sd/sq/dq
  let words = split(a:str, printf('%s\zs\s*\ze', pattern))
  " Extract wrapped words
  let words = map(words, 'matchstr(v:val, "^" . pattern . "$")')
  return words
endfunction " }}}

" Completers
" Note: It is a quite hard work so please help me to add other 
"       builtin completers (~ ~*)
let s:completers = {}
function! s:get_completers() abort " {{{
  " this function is maily for testing.
  return deepcopy(s:completers)
endfunction " }}}
function! s:completers.file(arglead, cmdline, cursorpos, args) abort " {{{
  " Ref: Vital.vim OptionParser.vim
  let candidates = split(glob(a:arglead . '*', 0), "\n")
  " substitute /home/<username> to ~/ if ~/ is specified
  if a:arglead =~# '^\~'
    let home_dir = expand('~')
    call map(candidates, printf("substitute(v:val, '^%s', '~', '')", home_dir))
  endif
  call map(candidates, "escape(isdirectory(v:val) ? v:val.'/' : v:val, ' \\')")
  return candidates
endfunction " }}}

" Parser
let s:parser = {
      \ '_long_arguments': {},
      \ '_short_arguments': {},
      \ '_conflict_groups': {},
      \ '_subordinations': {},
      \ '_depends': {},
      \ '_defaults': {},
      \ '_required': [],
      \ 'hooks': {},
      \}
function! s:new(...) abort " {{{
  let settings = extend({
        \ 'name': 'Arguments',
        \ 'auto_help': 1,
        \ 'validate_conflict_groups': 1,
        \ 'validate_subordinations': 1,
        \ 'validate_depends': 1,
        \ 'validate_required': 1,
        \ 'validate_kinds': 1,
        \ 'validate_unknown': 1,
        \}, get(a:000, 0, {}))
  let consts = {
        \ 'true': s:_true(),
        \ 'false': s:_false(),
        \ 'kinds': {
        \   'any': s:_any(),
        \   'switch': s:_switch(),
        \   'value': s:_value(),
        \   'choice': s:_choice(),
        \ },
        \ 'settings': settings,
        \}
  lockvar consts
  let parser = extend(deepcopy(s:parser), consts)
  if settings.auto_help
    call parser.add_argument('--help', '-h', 'show this help message', {
          \ 'kind': parser.kinds.switch,
          \})
  endif
  return parser
endfunction " }}}
function! s:parser.add_argument(name, ...) abort " {{{
  let name = a:name[2:]
  if a:0 == 0
    throw "add_argument require at least two argument (name, description)"
  elseif a:0 == 1
    let short = ''
    let description = a:1
    let settings = {}
  elseif a:0 == 2
    if type(a:2) == 1
      let short = a:1[1:]
      let description = a:2
      let settings = {}
    else
      let short = ''
      let description = a:1
      let settings = a:2
    endif
  else
    let short = a:1[1:]
    let description = a:2
    let settings = a:3
  endif
  let settings = extend({
        \ 'conflict_with': [],
        \ 'subordination_of': [],
        \ 'depend_on': [],
        \ 'required': 0,
        \ 'kind': self.kinds.switch,
        \ 'choices': [],
        \ 'complete': 0,
        \}, settings)
  let arg = {
        \ 'name': name,
        \ 'short': short,
        \ 'description': description,
        \}
  " register argument to long/short arguments
  let self._long_arguments[name] = arg
  if !empty(short)
    let self._short_arguments[short] = arg
  endif
  " register conflict groups
  let arg.conflict_with = s:_listalize(settings.conflict_with)
  for group in arg.conflict_with
    if !has_key(self._conflict_groups, group)
      let self._conflict_groups[group] = []
    endif
    call add(self._conflict_groups[group], name)
  endfor
  " register subordinations
  let arg.subordination_of = s:_listalize(settings.subordination_of)
  if !empty(arg.subordination_of)
    let self._subordinations[name] = arg.subordination_of
  endif
  " register depends
  let arg.depend_on = s:_listalize(settings.depend_on)
  if !empty(arg.depend_on)
    let self._depends[name] = arg.depend_on
  endif
  " register required
  if settings.required
    let arg.required = 1
    call add(self._required, name)
  else
    let arg.required = 0
  endif
  " kind/choices
  if !empty(settings.choices)
    let arg.choices = settings.choices
    let arg.kind = self.kinds.choice
    if type(settings.complete) == 0
      unlet settings['complete']
      let settings.complete = arg.choices
    endif
  else
    let arg.choices = []
    let arg.kind = settings.kind
  endif
  " complete
  if type(settings.complete) == 1
    let arg.complete = s:completers[settings.complete]
  elseif type(settings.complete) ==0
    let arg.complete = s:completers['file']
  else
    let arg.complete = settings.complete
  endif
  " default
  if has_key(settings, 'default')
    let arg.default = settings.default
    let self._defaults[name] = arg.default
  endif
  " fot futher manipulations
  return arg
endfunction " }}}

function! s:parser._call_hook(name, args) abort " {{{
  if has_key(self.hooks, a:name)
    return call(self.hooks[a:name], [a:args], self)
  endif
  return a:args
endfunction " }}}
function! s:parser._parse_cmdline(cmdline, ...) abort " {{{
  let args = extend({
        \ '__unknown__': [],
        \ '__args__': [],
        \ '__shellwords__': [],
        \}, get(a:000, 0, {}))
  let args = extend(deepcopy(self._defaults), args)
  let shellwords = s:shellwords(a:cmdline)
  let length = len(shellwords)
  let cursor = 0
  let args.__shellwords__ = shellwords
  while cursor < length
    let cword = shellwords[cursor]
    let nword = (length == cursor + 1) ? '' : shellwords[cursor+1]
    if cword =~# '^--\?'
      let name = matchstr(cword, '^--\?\zs.*\ze')
      " translate short argument name to long argument name
      if has_key(self._short_arguments, name)
        let name = self._short_arguments[name].name
      endif
      " is the specified argument registered?
      if has_key(self._long_arguments, name)
        if empty(nword) || nword =~# '^--\?'
          let Value = self.true
        else
          let Value = nword
          let cursor += 1
        endif
        let args[name] = Value
        call add(args.__args__, name)
        unlet Value
      else
        call add(args.__unknown__, cword)
      endif
    else
      call add(args.__unknown__, cword)
    endif
    let cursor += 1
  endwhile
  return args
endfunction " }}}
function! s:parser._parse_args(bang, range, ...) abort " {{{
  let args = {
        \ '__bang__': a:bang == '!',
        \ '__range__': a:range,
        \}
  let args = self._parse_cmdline(get(a:000, 0, ''), args)
  return args
endfunction " }}}
function! s:parser._validate_conflict_groups(args, ...) abort " {{{
  let settings = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {}))
  let argnames = keys(a:args)
  for [group, conflicts] in items(self._conflict_groups)
    let found = filter(copy(argnames), 'index(conflicts, v:val) > -1')
    if len(found) > 1
      if settings.verbose
        redraw
        echohl ErrorMsg
        echo 'Conflicted arguments:'
        echohl None
        echo printf('Arguments "%s" are conflicted.', join(found, ','))
              \ printf('The %s arguments listed below should not be specified in the same time', group)
        for name in conflicts
          echo '-' name
        endfor
      endif
      return 1
    endif
  endfor
  return 0
endfunction " }}}
function! s:parser._validate_subordinations(args, ...) abort " {{{
  let settings = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {}))
  let argnames = keys(a:args)
  if empty(self._subordinations)
    return 0
  endif
  let tried = 0
  for [name, subordination_of] in items(self._subordinations)
    if index(argnames, name) == -1
      continue
    endif
    let tried += 1
    let found = filter(copy(argnames), 'index(subordination_of, v:val) > -1')
    if len(found) != 0
      return 0
    endif
  endfor
  if tried == 0
    return 0
  endif
  " not found
  if settings.verbose
    redraw
    echohl ErrorMsg
    echo 'No parent argument is found:'
    echohl None
    echo printf('Arguments "%s" is subordination of the following', name)
    for parent in subordination_of
      echo '-' parent
    endfor
  endif
  return 1
endfunction " }}}
function! s:parser._validate_depends(args, ...) abort " {{{
  let settings = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {}))
  let argnames = keys(a:args)
  for [name, depend_on] in items(self._depends)
    if index(argnames, name) == -1
      continue
    endif
    let found = filter(copy(argnames), 'index(depend_on, v:val) > -1')
    if len(found) != len(depend_on)
      if settings.verbose
        redraw
        echohl ErrorMsg
        echo 'Required arguments are missing:'
        echohl None
        echo printf('Arguments "%s" depends on the following', name)
        for parent in depend_on
          echo '-' parent
        endfor
      endif
      return 1
    endif
  endfor
  return 0
endfunction " }}}
function! s:parser._validate_required(args, ...) abort " {{{
  let settings = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {}))
  let argnames = keys(a:args)
  let found = filter(copy(argnames), 'index(self._required, v:val) > -1')
  if len(found) != len(self._required)
    if settings.verbose
      redraw
      echohl ErrorMsg
      echo 'Required arguments are missing:'
      echohl None
      echo 'The following arguments are required.'
      for required in self._required
        echo '-' required
      endfor
    endif
    return 1
  endif
  return 0
endfunction " }}}
function! s:parser._validate_kinds(args, ...) abort " {{{
  let settings = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {}))
  for [name, Value] in items(a:args)
    if name =~# '^__.*__$'
      unlet Value
      continue
    endif

    let kind = self._long_arguments[name].kind
    if kind == self.kinds.switch
      if type(Value) != 2
        if settings.verbose
          redraw
          echohl ErrorMsg
          echo 'Invalid value in SWITCH:'
          echohl None
          echo printf('%s argument is SWITCH argument but %s is specified',
                \ name, Value)
        endif
        return 1
      endif
    elseif kind == self.kinds.value
      if type(Value) == 2
        if settings.verbose
          redraw
          echohl ErrorMsg
          echo 'No value is specified in VALUE:'
          echohl None
          echo printf('%s argument is VALUE argument but nothing is specified',
                \ name)
        endif
        return 1
      endif
    elseif kind == self.kinds.choice
      let choices = self._long_arguments[name].choices
      if type(Value) == 2
        if settings.verbose
          redraw
          echohl ErrorMsg
          echo 'No value is specified in CHOICE:'
          echohl None
          echo printf('%s argument is CHOICE argument but nothing is specified',
                \ name)
        endif
        return 1
      elseif index(choices, Value) == -1
        if settings.verbose
          redraw
          echohl ErrorMsg
          echo 'Invalid value is specified in CHOICE:'
          echohl None
          echo printf('%s argument is CHOICE argument but invalid value %s is specified',
                \ name, Value)
        endif
        return 1
      endif
    endif
    unlet Value
  endfor
  return 0
endfunction " }}}
function! s:parser._validate_unknown(args, ...) abort " {{{
  let settings = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {}))
  if !empty(a:args.__unknown__)
    if settings.verbose
      redraw
      echohl ErrorMsg
      echo 'Unknown options are specified:'
      echohl None
      echo 'The following unknown options are specified.'
      echo join(a:args.__unknown__, ' ')
    endif
    return 1
  endif
  return 0
endfunction " }}}
function! s:parser._transform(args) abort " {{{
  let args = copy(a:args)
  for [name, Value] in items(a:args)
    if name =~# '^__.*__$'
      unlet Value
      continue
    endif

    if type(Value) == 2
      unlet args[name]
      let args[name] = Value()
    endif

    unlet Value
  endfor
  return args
endfunction " }}}
function! s:parser.parse(bang, range, ...) abort " {{{
  let cmdline = get(a:000, 0, '')
  let settings = extend({
        \ 'verbose': 1,
        \}, get(a:000, 1, {}))
  let args = self._parse_args(a:bang, a:range, cmdline)
  " show help?
  if !empty(get(args, 'help', 0)) && self.settings.auto_help
    redraw
    echohl Title
    echo self.settings.name . ":"
    echohl None
    echo self.help()
    return {}
  endif
  " Call user defined function
  let args = self._call_hook('pre_validation', args)
  " Validation
  if self.settings.validate_conflict_groups &&
        \ self._validate_conflict_groups(args, settings) " {{{
    if settings.verbose
      echohl ErrorMsg
      echo 'Canceled.'
      echohl None
    endif
    return {}
  endif " }}}
  if self.settings.validate_subordinations &&
        \ self._validate_subordinations(args, settings) " {{{
    if settings.verbose
      echohl ErrorMsg
      echo 'Canceled.'
      echohl None
    endif
    return {}
  endif " }}}
  if self.settings.validate_depends &&
        \ self._validate_depends(args, settings) " {{{
    if settings.verbose
      echohl ErrorMsg
      echo 'Canceled.'
      echohl None
    endif
    return {}
  endif " }}}
  if self.settings.validate_required &&
        \ self._validate_required(args, settings) " {{{
    if settings.verbose
      echohl ErrorMsg
      echo 'Canceled.'
      echohl None
    endif
    return {}
  endif " }}}
  if self.settings.validate_kinds &&
        \ self._validate_kinds(args, settings) " {{{
    if settings.verbose
      echohl ErrorMsg
      echo 'Canceled.'
      echohl None
    endif
    return {}
  endif " }}}
  if self.settings.validate_unknown &&
        \ self._validate_unknown(args, settings) " {{{
    if settings.verbose
      echohl ErrorMsg
      echo 'Canceled.'
      echohl None
    endif
    return {}
  endif " }}}
  " Call user defined function
  let args = self._call_hook('post_validation', args)
  let args = self._call_hook('pre_transformation', args)
  " Transform
  let args = self._transform(args)
  " Call user defined function
  let args = self._call_hook('post_transformation', args)
  return args
endfunction " }}}

function! s:parser.has_conflict_with(name, args) abort " {{{
  let conflict_groups = self._long_arguments[a:name].conflict_with
  let argnames = keys(a:args)
  for group in conflict_groups
    let conflicts = self._conflict_groups[group]
    let found = filter(copy(argnames), 'index(conflicts, v:val) > -1')
    if len(found) > 0
      return 1
    endif
  endfor
  return 0
endfunction " }}}
function! s:parser.has_subordination_of(name, args) abort " {{{
  let parents = self._long_arguments[a:name].subordination_of
  let argnames = keys(a:args)
  let found = filter(copy(argnames), 'index(parents, v:val) > -1')
  if len(found) > 0
    return 1
  endif
  return 0
endfunction " }}}
function! s:parser.has_depend_on(name, args) abort " {{{
  let parents = self._long_arguments[a:name].depend_on
  let argnames = keys(a:args)
  let found = filter(copy(argnames), 'index(parents, v:val) > -1')
  if len(found) == len(parents)
    return 1
  endif
  return 0
endfunction " }}}

function! s:parser._complete_long_argument(arglead, args) abort " {{{
  let candidates = []
  for [name, arg] in items(self._long_arguments)
    if has_key(a:args, name)
      continue
    endif
    let conflict_with = (empty(arg.conflict_with) ||
          \ !self.has_conflict_with(name, a:args))
    let subordination_of = (empty(arg.subordination_of) ||
          \ self.has_subordination_of(name, a:args))
    if conflict_with && subordination_of
      call add(candidates, name)
    endif
  endfor
  call map(candidates, '"--" . v:val')
  return filter(candidates, printf('v:val =~# "^%s"', a:arglead))
endfunction " }}}
function! s:parser._complete_short_argument(arglead, args) abort " {{{
  let candidates = []
  for [short_name, arg] in items(self._short_arguments)
    let name = self._short_arguments[short_name].name
    if has_key(a:args, name)
      continue
    endif
    let conflict_with = (empty(arg.conflict_with) ||
          \ !self.has_conflict_with(name, a:args))
    let subordination_of = (empty(arg.subordination_of) ||
          \ self.has_subordination_of(name, a:args))
    if conflict_with && subordination_of
      call add(candidates, short_name)
    endif
  endfor
  call map(candidates, '"-" . v:val')
  return filter(candidates, printf('v:val =~# "^%s"', a:arglead))
endfunction " }}}
function! s:parser._complete_argument_value(arglead, cmdline, cursorpos, args) abort " {{{
  let last_argname = a:args.__args__[-1]
  let last_arg = self._long_arguments[last_argname]

  if empty(last_arg.complete)
    return []
  elseif type(last_arg.complete) == 2
    return last_arg.complete(a:arglead, a:cmdline, a:cursorpos, a:args)
  else
    " complete should be a list
    return filter(copy(last_arg.complete), 'v:val =~# "^" . a:arglead')
  endif
endfunction " }}}
function! s:parser.complete(arglead, cmdline, cursorpos) abort " {{{
  " parse 'cmdline' without validation
  let args = self._parse_cmdline(a:cmdline)
  let candidates = []
  let args = self._call_hook('pre_completion', args)
  " check previous inputs to determine which completion method is the best
  if len(args.__args__) > 0
    let last_argname = args.__args__[-1]
    let Last_argvalue = args[last_argname]
    let last_arg = self._long_arguments[last_argname]
    if type(Last_argvalue) == 2 && (
          \ last_arg.kind == self.kinds.value ||
          \ last_arg.kind == self.kinds.choice)
      " if the kind is value or choice and the value have not specified yet
      let candidates = self._complete_argument_value(
            \ a:arglead, a:cmdline, a:cursorpos, args)
    elseif type(Last_argvalue) == 2 &&
          \ last_arg.kind == self.kinds.any &&
          \ a:arglead !~# '^--\?'
      if !empty(last_arg.complete)
        " if the kind is any and the value have not specified yet
        let candidates = self._complete_argument_value(
              \ a:arglead, a:cmdline, a:cursorpos, args)
      endif
    endif
  endif
  if empty(candidates)
    if a:arglead =~# '^--'
      let candidates = self._complete_long_argument(a:arglead, args)
    elseif a:arglead =~# '^-'
      let long_arguments = self._complete_long_argument('-' . a:arglead, args)
      let short_arguments = self._complete_short_argument(a:arglead, args)
      let candidates = long_arguments + short_arguments
    else
      " return argument list
      let long_arguments = self._complete_long_argument('--' . a:arglead, args)
      let short_arguments = self._complete_short_argument('-' . a:arglead, args)
      let candidates = long_arguments + short_arguments
    endif
  endif
  let candidates = self._call_hook('post_completion', candidates)
  return candidates
endfunction " }}}

function! s:parser._format_definition(arg) abort " {{{
  if a:arg.kind == self.kinds.any
    let value = printf(" [%s]", toupper(a:arg.name))
  elseif a:arg.kind == self.kinds.value
    let value = printf(" %s", toupper(a:arg.name))
  elseif a:arg.kind == self.kinds.choice
    let value = " {choice}"
  else
    let value = ""
  endif

  if empty(a:arg.short)
    let short = "   "
  else
    let short = printf("-%s,", a:arg.short)
  endif

  return printf("%s --%s%s", short, a:arg.name, value)
endfunction " }}}
function! s:parser._format_description(arg) abort " {{{
  let kind = printf("(kind: %s)\n", a:arg.kind)
  if empty(a:arg.conflict_with)
    let conflict_with = ""
  else
    let conflict_with = printf(
          \ "(conflict_with: %s)\n",
          \ join(a:arg.conflict_with, ", ")
          \)
  endif
  if empty(a:arg.subordination_of)
    let subordination_of = ""
  else
    let subordination_of = printf(
          \ "(subordination_of: %s)\n",
          \ join(a:arg.subordination_of, ", ")
          \)
  endif
  if empty(a:arg.depend_on)
    let depend_on = ""
  else
    let depend_on = printf(
          \ "(depend_on: %s)\n",
          \ join(a:arg.depend_on, ", ")
          \)
  endif
  if !a:arg.required
    let required = ""
  else
    let required = "(required)\n"
  endif
  if empty(a:arg.choices)
    let choices = ""
  else
    let choices = printf(
          \ "({choice}: %s)\n", 
          \ join(a:arg.choices, ", ")
          \)
  endif
  return printf("%s\n%s%s%s%s%s%s", a:arg.description,
        \ kind,
        \ conflict_with, subordination_of, depend_on,
        \ required, choices,
        \)
endfunction " }}}
function! s:parser.help() abort " {{{
  let definitions = map(
        \ values(self._long_arguments),
        \ 'self._format_definition(v:val)'
        \)
  let descriptions = map(
        \ values(self._long_arguments),
        \ 'self._format_description(v:val)'
        \)
  " find a longest length of definitions
  let max_length = len(s:List.max_by(definitions, 'len(v:val)'))
  " combine definitions and descriptions
  let rows = []
  for [definition, description] in s:List.zip(definitions, descriptions)
    let _descriptions = split(description, "\n")
    call add(rows, printf(printf("%%-%ds  %%s", max_length),
          \ definition, _descriptions[0]))
    for _description in _descriptions[1:]
      call add(rows, printf(printf("%%-%ds  %%s", max_length),
            \ "", _description))
    endfor
    call add(rows, "")
  endfor
  return join(rows, "\n")
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
