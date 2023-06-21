#!/bin/sh source-this-script

_PS1Panel_todo()
{
    [ -n "${_PS1GitRoot:-}" ] \
	&& typeset localTodoFilespec="${_PS1GitRoot}/todo.txt" \
	&& [ -r "$localTodoFilespec" ] \
	|| return

    typeset todoCount="$(wc --lines <"$localTodoFilespec")"
    [ $todoCount -gt 0 ] || return

    printf 'TODO:%d\n' "$todoCount"
}
