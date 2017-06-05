#!/bin/bash

if ! ( [ -n "$1" ] && [[ "$1" == "-t" ]] ); then
    # Creates a copy of the script to tmp for it to be executed in a new terminal
    mkdir /tmp/Superscript 2>/dev/null
    sed -n '11,$p' $0 >| /tmp/Superscript/superscript
    gnome-terminal --title "Superscript" --geometry 49x39+800+250 -e "bash /tmp/Superscript/superscript" 2>/dev/null
    exit
fi

cleanup() {
    # tput clear
    tput cvvis
    stty echo
    # rm -rf /tmp/Superscript 2>/dev/null
}
trap cleanup EXIT

sprites() {
    sprite['ship']='\e[1m\u23c5\e[0m'       # ⏅
    sprite['projectile']='\u0027'           # '
    sprite['enemy1']='\e[1m\u25bf\e[0m'     # ▿
    sprite['enemy2']='\u2352'               # ⍒
    sprite['enemy3']='\u236b'               # ⍫
    sprite['boss1']='\e[1m\u2362\e[0m'      # ⍢
    sprite['boss2']='\e[1m\u2354\e[0m'      # ⍔
    sprite['explosion1']='\u2058'           # ⁘
    sprite['explosion2']='\u205b'           # ⁛
    sprite['wall0']=' '                     # Null
    sprite['wall1']='\u2591'                # Light
    sprite['wall2']='\u2592'                # Medium
    sprite['wall3']='\u2593'                # Dark
    sprite['wall4']='\u2588'                # Full
}

destroy() {
    if [ -n "$4" ]; then
        tput cup $3 $4
        printf "%$(( ${#words[$1]}+2 ))s"
    fi
    tput cup $3 $2
    echo -en "${sprite[explosion1]}"
    sleep 0.05
    echo -en "\b${sprite[explosion2]}"
    sleep 0.05
    echo -en "\b "
    if (( $1>-1 )); then
        if [ -n "$word_focus" ]; then
            (( $1<$word_focus )) && (( word_focus-- ))
            (( $1==$word_focus )) && unset match stun word_focus
        fi
        words=( ${words[@]:0:$1} ${words[@]:$(( $1+1 ))} )
        enemy_col=( ${enemy_col[@]:0:$1} ${enemy_col[@]:$(( $1+1 ))} )
        enemy_row=( ${enemy_row[@]:0:$1} ${enemy_row[@]:$(( $1+1 ))} )
    fi
}

shoot() {
    tput cup 35 $ref_col
    echo -en " "
    tput cup 35 $next_ref_col
    echo -en "${sprite[ship]}"
    ref_col=$next_ref_col
    tput cup 34 $ref_col
    for (( p=34; p>${enemy_row[$1]}; p-- )); do
        tput cup $p $ref_col
        echo -en "${sprite[projectile]}"
        tput cup $(( $p+1 )) $ref_col
        echo -en " "
        sleep 0.001
    done
    tput cup $(( $p+1 )) $ref_col
    echo -en " "
    word="\e[32;1m${words[$word_focus]:0:$match}\e[39m${words[$word_focus]:$match}\e[0m"
    draw_sprites 1 "$word"
}

draw_sprites() {
    if (( $new_level )); then
        tput cup 19 21
        echo -en "\e[1mLEVEL $level\e[0m"
        sleep 2
        tput cup 19 21
        echo -n "         "
        tput cup 35 1
        echo -n "                                               "
        new_level=0
    fi
    if (( $1 )); then
        for (( l=0; l<(${#words[@]}+1); l++ )); do
            if [ -n "$word_focus" ]; then
                if [ -n "$2" ]; then
                    word="$2"
                    l=$word_focus
                else
                    (( $l==$word_focus )) && continue
                    if (( $l==${#words[@]} )); then
                        l=$word_focus
                        word="\e[32;1m${words[$l]:0:$match}\e[39m${words[$l]:$match}\e[0m"
                    else
                        word=${words[$l]}
                    fi
                fi
            else
                (( $l==${#words[@]} )) && break
                word=${words[$l]}
            fi
            e_row=${enemy_row[$l]}
            (( $e_row<1 )) && continue
            e_col=${enemy_col[$l]}
            word_len=${#words[$l]}

            if (( $e_row==35 && ${enemy_col[$l]}==$ref_col )); then
                destroy $l ${enemy_col[$l]} $(( $e_row-1 ))
                destroy -1 $ref_col 35
                read
                exit
            fi

            if (( $e_row>35 )); then
                wall_col=${enemy_col[$l]}
                if (( ${wall_log[$wall_col]}>0 )); then
                    if (( $word_len<13 )); then
                        wall_kill=$(( ($word_len+2)/3 ))
                    else
                        wall_kill=4
                    fi
                    (( wall_log[$wall_col]-=$wall_kill ))
                    tput cup $e_row $wall_col
                    echo -en "${sprite[wall${wall_log[$wall_col]}]}"
                    destroy $l ${enemy_col[$l]} $(( $e_row-1 ))
                    (( l-- ))
                    continue
                else
                    tput cup $(( $e_row-1 )) $e_col
                    echo -n " "
                    (( $e_row==37 )) && { read; exit; } #TODO
                fi
            fi

            if (( $e_row>1 && $e_row<36 )); then
                if (( $e_row==$highest )) || [ -z "$word_focus" ] || \
                        ( [ -n "$word_focus" ] && (( $l!=$word_focus )) ); then
                    tput cup $(( $e_row-1 )) 1
                    echo -n "                                               "
                fi
            fi
            if (( $word_len>(46-$e_col) )); then
                (( e_col-=($word_len+1) ))
                print_word=1
                word+=" "
            else
                print_word=0
                word=" $word"
            fi
            if (( $e_row>34 )); then
                unset word
                (( print_word )) && (( e_col+=($word_len+1) ))
            fi
            tput cup $e_row $e_col
            if (( $word_len<4 )); then
                if (( $print_word )); then
                    echo -en "$word${sprite[enemy1]}"
                else
                    echo -en "${sprite[enemy1]}$word"
                fi
            elif (( $word_len<7 )); then
                if (( $print_word )); then
                    echo -en "$word${sprite[enemy2]}"
                else
                    echo -en "${sprite[enemy2]}$word"
                fi
            elif (( $word_len<10 )); then
                if (( $print_word )); then
                    echo -en "$word${sprite[enemy3]}"
                else
                    echo -en "${sprite[enemy3]}$word"
                fi
            elif (( $word_len<13 )); then
                if (( $print_word )); then
                    echo -en "$word${sprite[boss1]}"
                else
                    echo -en "${sprite[boss1]}$word"
                fi
            elif (( $word_len>12 )); then
                if (( $print_word )); then
                    echo -en "$word${sprite[boss2]}"
                else
                    echo -en "${sprite[boss2]}$word"
                fi
            fi
            ( [ -n "$word_focus" ] && (( $l==$word_focus )) ) && break
        done
        ( [ -n "$match" ] && (( $match==$word_len )) ) && destroy $word_focus ${enemy_col[$word_focus]} $e_row $e_col
    fi
    [ -n "$2" ] && return
    tput cup 35 $ref_col
    echo -en "${sprite[ship]}"
}

load_enemies() {
    words=( $( sed -n "${level}p" "$text" ) )
    used_cols="0"
    e_row=0
    for (( i=0; i<${#words[@]}; i++ )); do
        if (( ${#words[$i]}>40 )); then
            words=( ${words[@]:0:$i} ${words[@]:$(( $i+1 ))} )
            continue
        fi
        enemy_row[$i]=$e_row
        (( e_row-- ))
        while true; do
            e_col=$(( $RANDOM%46+1 ))
            [[ " $used_cols " =~ " $e_col " ]] || break
        done
        enemy_col[$i]=$e_col
        used_cols+=" $e_col"
    done
    highest=$e_row
}

game_loop() {
    while true; do
        if (( ${#words[@]}==0 )); then
            (( level++ ))
            new_level=1
            (( $speed>2 )) && speed=$( printf '%02d' $(( speed-=2 )) )
            load_enemies
        fi
        draw_sprites $draw_enemies
        pre_time=$( date '+%2N' | sed 's/^0//' )
        read -sn1 -t0.$(( $speed-$time_taken )) key
        if (( $?!=142 )); then
            [[ "$key" == $'\e' ]] && exit
            # Clear input buffer
            # read -t 0.0001 -n 10000 discard
            if [ -z "$word_focus" ]; then
                for (( w=0; w<${#words[@]}; w++ )); do
                    if (( ${enemy_row[$w]}>0 && ${enemy_row[$w]}<35 )); then
                        if [[ "$key" == "${words[$w]:0:1}" ]]; then
                            next_ref_col=${enemy_col[$w]}
                            match=1
                            word_focus=$w
                            stun=$w
                            shoot $w
                            break
                        fi
                    fi
                done
            else
                if [[ "$key" == "${words[$word_focus]:$match:1}" ]]; then
                    (( match++ ))
                    stun=$word_focus
                    shoot $word_focus
                fi
            fi
        fi
        speed=$( sed 's/^0*//' <<< $speed )
        post_time=$( date '+%2N' | sed 's/^0//' )
        (( $post_time<$pre_time )) && (( post_time+=100 ))
        if (( $time_taken )); then
            (( time_taken+=($post_time-$pre_time) ))
        else
            time_taken=$(( $post_time-$pre_time ))
        fi
        if (( $time_taken<$speed )); then
            draw_enemies=0
        else
            highest=36
            for (( s=0; s<${#words[@]}; s++ )); do
                ( [ -n "$stun" ] && [[ "${words[$s]}" == "${words[$stun]}" ]] ) && continue
                (( enemy_row[$s]++ ))
                (( ${enemy_row[$s]}<$highest )) && highest=${enemy_row[$s]}
            done
            unset stun
            draw_enemies=1
            time_taken=0
        fi
    done
}

new_game() {
    text=/tmp/Superscript/text
    tr '[A-Z]' '[a-z]' < "$text_file" | tr '.' '\n' | \
            sed 's/[^([:alnum:]| )]//g;/^ *$/d' >| "$text"
    clear_map 37
    tput cup 36 1
    wall_log=()
    for (( b=0; b<47; b++ )); do
        echo -en "${sprite[wall0]}"
        wall_log+=( 0 )
    done
    level=1
    tput cup 19 21
    echo -en "\e[1mLEVEL $level\e[0m"
    sleep 2
    tput cup 19 21
    echo -n "         "
    new_level=0
    speed=60
    ref_col=24
    draw_enemies=1
    time_taken=0
    load_enemies
    game_loop
}

set_text() {
    return
}

clear_map() {
    # Render blank map
    tput reset
    echo '┌───────────────────────────────────────────────┐'
    for (( b=1; b<$1; b++ )); do
        echo '│                                               │'
    done
    echo -n '└───────────────────────────────────────────────┘'
    tput civis
}

main_menu() {
    # Clear screen
    tput clear
    # Display the main menu
    clear_map 38
    tput cup 2 18
    echo "Ben  Pitman's"
    tput cup 4 14
    echo -e '\e[1mS U P E R S C R I P T\e[0m'
    tput cup 10 20
    echo -e '\e[1mCONTROLS\e[0m'
    tput cup 14 11
    echo 'Ctrl-C       -       Quit'
    selected=3
    # Get/Create current high score
    hs_log=/home/$USER/.superscript_highscore
    [ -s "$hs_log" ] || echo "0" >| $hs_log
    high_score=$( < $hs_log )
    text_file=~/text.txt
    tput civis  # Disable cursor blinker
    while true; do
        case $selected in
            *)  unset START SCORES TEXT QUIT;;&
            3)  START='\e[1;36mSTART\e[0m'
                redirect="new_game";;
            2)  SCORES='\e[1;36mHIGH SCORES\e[0m'
                redirect="show_scores";;
            1)  TEXT='\e[1;36mCHOOSE TEXT\e[0m'
                redirect="set_text";;
            0)  QUIT='\e[1;36mQUIT\e[0m';;
        esac
        set ${START:='START'} \
            ${SCORES:='HIGH SCORES'} \
            ${TEXT:='CHOOSE TEXT'} \
            ${QUIT:='QUIT'}
        tput cup 18 22
        echo -e "$START"
        tput cup 20 19
        echo -e "$SCORES"
        tput cup 22 19
        echo -e "$TEXT"
        tput cup 24 22
        echo -e "$QUIT"
        read -sn1 key1
        read -sn1 -t 0.0001 key2
        read -sn1 -t 0.0001 key3
        case $key3 in
           A)   (( $selected==3 )) && selected=0 || (( selected++ ));; # Up
           B)   (( $selected==0 )) && selected=3 || (( selected-- ));; # Down
        esac
        if [ -z "$key1" ]; then
            if (( $selected )); then
                $redirect
            else
                exit
            fi
        fi
        unset key1 key2 key3
    done
}

declare -A sprite
sprites

stty -echo
main_menu
