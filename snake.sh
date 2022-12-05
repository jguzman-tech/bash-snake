#!/bin/bash

# Author: Joseph Guzman (github uid: jguzman-tech)
# Date: 2022-11-26
# Description: A pure-bash implementation of the classic Snake game

# notes on comptaibility:
# 1. features like colors and unicode characters were omitted due because more
#    work is needed in ensuring compatbility in the terminal emulator (may be
#    changed in a future update)
# 2. xterm and gnome-terminal do not support all ACS_* chars, like the arrows
#    * EVEN THOUGH they clearly have unicode support, tput does not recognize those chars
#    * you can prove this with "terminfo -l $TERM", it omits the arrows in the acsc field
# 3. tmux does not support the 'tput ech' or 'tput del' directives
#    * you can still overwrite chars with spaces to create a visual erase effect, same idea
# 4. I make use of non-POSIX GNU coreutils commands and tput
#    This program will not work if you do not have the ncurses or GNU coreutils package
#    installed on your system. Mac users may be able to get around this with homebrew.

cleanup() {
    tput rmacs
    tput rmcup
    stty echo
    tput cnorm
    exit
}

init_board() {
    
    # title
    tput cup 0 0
    printf " bash-snake -- difficulty: medium"

    tput smacs
    # all printed chars will be replaced with ACS equivalent from here until the 'tput rmacs statement'
    # see 'man terminfo' for details
    
    # top side
    tput cup "$UL_Y" "$UL_X"
    printf 'l'
    printf 'q%.0s' $( seq $((UL_X+1)) $((UR_X-1)) )

    # right side
    tput cup "$UR_Y" "$UR_X"
    printf 'k'
    for y in $( seq $((UR_Y+1)) $((LR_Y-1)) ); do
        tput cup "$y" "$UR_X"
        printf 'x'
    done

    # bottom side
    tput cup "$LR_Y" "$LR_X"
    printf 'j'
    for x in $( seq $((LR_X-1)) -1 $((LL_X+1)) ); do
        tput cup 20 "$x"
        printf 'q'
    done

    # left side
    tput cup "$LL_Y" "$LL_X"
    printf 'm'
    for y in $( seq $((LL_Y-1)) -1 $((UL_Y+1)) ); do
        tput cup "$y" 0
        printf 'x'
    done
    tput rmacs

    # show controls
    tput cup 21 0
    printf 'Move: <arrow keys>'
    tput cup 22 0
    printf 'Menu: q (not yet implemented)'
    tput cup 23 0
    printf 'Quit: Ctrl-C'

    # show score
    tput cup 21 69
    printf 'Score: %4d' 0
    
    sleep 1
}

intro() {
    splash_message='bash-snake (A pure-bash implementation of the classic Snake game) By Joseph Guzman
Github: https://github.com/jguzman-tech/bash-snake'

    tput cup 0 0
    printf "%s\n" "$splash_message"

    tput cup "$((LINES-1))"
    printf 'Press Control-C to quit at any time'
    
    tput cup "$LINES" 0
    printf 'STARTING NOW!!!'
    sleep 1
    
    tput clear   
}

# wait for user input
# also acts as the time keeper for the game by waiting for "$INTERVAL" seconds
input_wait() {
    local START="$(date +'%s.%N')"
    local END="$(awk -v x="$START" -v y="$INTERVAL" 'BEGIN { printf "%.9f", x+y }')"
    if LC_CTYPE=C read -rs -t "$INTERVAL" -N 3; then
        case "$REPLY" in
            $'\x1b'$'\x5b'$'\x41')
                direction=up
                ;;
            $'\x1b'$'\x5b'$'\x42')
                direction=down
                ;;
            $'\x1b'$'\x5b'$'\x43')
                direction=right
                ;;
            $'\x1b'$'\x5b'$'\x44')
                direction=left
                ;;
            *)
                direction="${snake[$head_y:$head_x]}"
                ;;
        esac

        snake[$head_y:$head_x]="$direction"
        echo "cursor direction = '$direction'" >> /dev/stderr
        local NOW="$(date +'%s.%N')"
        local DIFF="$(awk -v x="$NOW" -v y="$END" 'BEGIN { z=y-x; if(z>0) printf "%.9f", z }')"
        [[ -n "$DIFF" ]] && sleep "$DIFF"
    else
        direction="${snake[$head_y:$head_x]}"
    fi
}

# populates the apple associative array
make_rand_apple() {
    local y x
    
    y="$(( (RANDOM % 18) + 2  ))" # range: [2:19]
    x="$(( (RANDOM % 78) + 1 ))" # range: [1:78]

    while [[ -n "${snake[$y:$x]}" ]]; do
            y="$(( (RANDOM % 18) + 2  ))" # range: [2:19]
            x="$(( (RANDOM % 78) + 1 ))" # range: [1:78]
    done

    apples[$y:$x]=1
    tput cup "$y" "$x"
    printf 'O'
}

game_over() {
    tput cup "2" "34"
    printf 'GAME OVER'
    sleep 2
    cleanup
}

#### MAIN ####

tput smcup # save initial cursor position
tput enacs # enable Alternate Character Set
stty -echo # hide all user input
tput civis # hide cursor

trap cleanup SIGINT

LINES="$(tput lines)"
COLS="$(tput cols)"
INTERVAL="0.075" # update interval in seconds
RATE="4" # spawn an apple at a rate of one per four frames
SCORE=0

if [[ "$LINES" -lt 24 || "$COLS" -lt 80 ]]; then
    tput rmcup
    printf "Error: terminal must be at least 80 rows by 24 columns\n" > /dev/stderr
    exit 1
fi

UL_Y=1; UL_X=0
UR_Y=1; UR_X=79
LR_Y=20; LR_X=79
LL_Y=20; LL_X=0

intro
init_board

# we'll keep track of the state of the snake with 5 variables:
# - snake: an associative array
# -- key: "Y:X"
# -- value: 'up', 'down', 'left', or 'right'
# - head_y, head_x: index of head
# - tail_y, tail_x: index of the tail

# snake's index will be the Y:X coordinates
# these are with respect to the the global bounds
declare -A snake

head_y=7
head_x=6
snake[$head_y:$head_x]=right
tail_y=7
tail_x=6

# holds apple coordinates
declare -A apples

tput rmacs

# draw snake head
tput cup "$head_y" "$head_x"
printf "$(tput rev) $(tput sgr0)"

# main game loop below:
frame=0
while :; do
    frame="$((frame+1))"
    echo "debug -- $frame (init): head_x='$head_x', head_y='$head_y', tail_x='$tail_x', tail_y='$tail_y', '$(declare -p snake)'" >> /dev/stderr

    # spawn an apple if it is time
    [[ "$((frame % RATE))" == 0 ]] && make_rand_apple
    
    input_wait

    if [[ "$SCORE" -eq 0 ]]; then
        tail_y="$head_y"
        tail_x="$head_x"
    fi
    
    case "$direction" in
        up)
            head_y=$((head_y-1))
            ;;
        down)
            head_y=$((head_y+1))
            ;;
        right)
            head_x=$((head_x+1))
            ;;
        left)
            head_x=$((head_x-1))
            ;;
        *)
            echo "debug -- $frame (move-error): head_x='$head_x', head_y='$head_y', direction='$direction', '$(declare -p snake)'" >> /dev/stderr
            echo 'error (head move) -- direction was  '"$direction" >> /dev/stderr
            cleanup
            ;;
    esac
    echo "debug -- $frame (move): head_x='$head_x', head_y='$head_y', direction='$direction', '$(declare -p snake)'" >> /dev/stderr

    # if the next space is already a part of the snake
    # then this means the snake ran into itself :(
    if [[ -n "${snake[$head_y:$head_x]}" ]]; then
        game_over
    else
        snake[$head_y:$head_x]="$direction"
    fi
    tput cup "$head_y" "$head_x"
    printf "$(tput rev) $(tput sgr0)"

    # to grow the snake we can simply skip the tail erase op, and increment score
    # grow if head collides with an apple, then remember to delete the apple!
    if [ -z "${apples[$head_y:$head_x]}" ]; then

        direction="${snake[$tail_y:$tail_x]}"
        unset "snake[$tail_y:$tail_x]"
        tput cup "$tail_y" "$tail_x"
        printf ' '
        case "$direction" in
            up)
                tail_y=$((tail_y-1))
                ;;
            down)
                tail_y=$((tail_y+1))
                ;;
            right)
                tail_x=$((tail_x+1))
                ;;
            left)
                tail_x=$((tail_x-1))
                ;;
            *)
                echo "debug -- $frame (erase-error): tail_x='$tail_x', tail_y='$tail_y', direction='$direction', '$(declare -p snake)'" >> /dev/stderr
                echo 'error (tail move) -- direction was '"$direction" >> /dev/stderr
                cleanup
                ;;
        esac
        echo "debug -- $frame (erase): tail_x='$tail_x', tail_y='$tail_y', direction='$direction', '$(declare -p snake)'" >> /dev/stderr
    else
        SCORE="$((SCORE+1))"
        unset "apple[$head_y:$head_x]"
    fi

    # validate that snake is still in bounds: (this is a loss condition)
    if [[ "$head_y" -le 1 || "$head_y" -ge 20 || "$head_x" -le 0 || "$head_x" -ge 79 ]]; then
        game_over
    fi

    tput cup 21 69
    printf 'Score: %4d' "$SCORE"
done

cleanup
