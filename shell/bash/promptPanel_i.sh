#!/bin/bash source-this-script

_PS1Panel_todo()
{
    [ -n "${_PS1TodoLocalTodoDir:-}" ] \
	&& local localTodoFilespec="${_PS1TodoLocalTodoDir}/todo.txt" \
	&& [ -r "$localTodoFilespec" ] \
	|| return

    local todoCount="$(wc --lines <"$localTodoFilespec")"
    [ $todoCount -gt 0 ] || return

    printf 'TODO:%d\n' "$todoCount"
}

_PS1TodoLocal()
{
    < <(todo-local.sh location) IFS=$'\n' read -r _PS1TodoLocalTodoDir

    [ -n "$_PS1TodoLocalTodoDir" ] \
	&& export _PS1TodoLocalTodoDir \
	|| unset _PS1TodoLocalTodoDir
}

commandSequenceMunge _PS1OnChangeDirectory _PS1TodoLocal
