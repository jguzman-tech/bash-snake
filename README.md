# bash-snake
A pure-bash implementation of the classic Snake game for your terminal

# Installation / Execution
This repo features one stand-alone bash script. You can clone/download the repo and execute the script directly. Your linux distro likely comes with the dependent pacakges already.

This is a rough draft currently. You NEED to redirect the standard error stream for the interface to show up properly, otherwise the debug messages will break the ncurses-like interface.

This program makes use of bash, GNU coreutils, and tput. The tput command will come from the ncurses package on your linux system usually. This was not tested on Mac.

Example invocation:
```
./snake.sh 2>/dev/null
```

Here's a gif of me playing the game.

# Future Work
1. implementing a menu that lets you adjust the speed of the game, possibly controls too
2. instant replay
3. writing past high scores to ~/.local to allow the game to keep track of your scores persistently
4. using a debug flag instead of writting to stderr
5. experiment with different ASCII/UNICODE characters for the snake, to make it more clear what direction you're moving, the bounds, and what part gets struck when you lose (general UI)
