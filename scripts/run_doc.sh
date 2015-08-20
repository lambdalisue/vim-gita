#!/usr/bin/env bash
vim --cmd "try | helptags doc/ | catch | cquit | endtry" --cmd quit
