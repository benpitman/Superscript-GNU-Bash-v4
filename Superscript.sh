#!/bin/bash

mkdir /tmp/Superscript 2>/dev/null
if ! ( [ -n "$1" ] && [[ "$1" == "-t" ]] ); then
    # Creates a copy of the script to tmp for it to be executed in a new terminal
    sed -n '11,$p' $0 >| /tmp/Superscript/superscript
    gnome-terminal --title "Superscript" --geometry 49x39+800+250 -e "bash /tmp/Superscript/superscript" 2>/dev/null
    exit
fi

cleanup() {
    # tput clear
    tput cvvis
    stty echo
    # rm -rf /tmp/Superscript 2>/dev/null
    tput cup 39 49
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
    sprite['wall1']='\u2591'                # Light
    sprite['wall2']='\u2592'                # Medium
    sprite['wall3']='\u2593'                # Dark
    sprite['wall4']='\u2588'                # Full
}

game_over() {
    while (( ${#words[@]}>0 )); do
        destroy_enemy 1 0 ${enemy_row[0]} ${enemy_col[0]}
        sleep 0.1
    done
    for (( dw=0; dw<47; dw++ )); do
        if (( ${wall_log[$dw]}>0 )); then
            destroy_wall $(( $dw+1 ))
            score_modifier 1 $(( ${wall_log[$dw]}*100 ))
        fi
        sleep 0.02
    done
    exit
    #TODO score screen with name and date
}

destroy_wall() {
    tput cup 36 $1
    printf "${sprite[explosion2]}"
    sleep 0.05
    printf "\b "
}

destroy_enemy() {
    if (( $1 )); then
        tput cup $3 $4
        printf "%$(( ${#words[$2]}+2 ))s"
    fi
    d_col=$4
    if (( $2>-1 )); then
        (( ${print_left[$2]} )) && d_col=${used_cols[$2]}
    fi
    tput cup $3 $d_col
    printf "${sprite[explosion1]}"
    sleep 0.05
    printf "\b${sprite[explosion2]}"
    sleep 0.05
    printf "\b "
    if (( $2>-1 )); then
        if [ -n "$word_focus" ]; then
            if (( $2==$word_focus )); then
                unset match stun word_focus
            elif (( $2<$word_focus )); then
                (( word_focus-- ))
            fi
        fi
        words=( ${words[@]:0:$2} ${words[@]:$(( $2+1 ))} )
        enemy_col=( ${enemy_col[@]:0:$2} ${enemy_col[@]:$(( $2+1 ))} )
        enemy_row=( ${enemy_row[@]:0:$2} ${enemy_row[@]:$(( $2+1 ))} )
        used_cols=( ${used_cols[@]:0:$2} ${used_cols[@]:$(( $2+1 ))} )
        enemies=( ${enemies[@]:0:$2} ${enemies[@]:$(( $2+1 ))} )
        print_left=( ${print_left[@]:0:$2} ${print_left[@]:$(( $2+1 ))} )
    fi
}

score_modifier() {
    if (( $1 )); then
        if (( $progress_bar>0 && $progress_bar%43==0 )); then
            if (( $colour<7 )); then
                (( colour++ ))
                progress_bar=0
            fi
            (( score_mult++ ))
        fi
        (( progress_bar++ ))
        (( overall_progress++ ))
        if [ -z "$2" ]; then
            read score <<< $( bc <<< "$score+($overall_progress*$score_mult)" )
        else
            read score <<< $( bc <<< "$score+$2" )
        fi
    else
        progress_bar=0
        overall_progress=0
        colour=1
        score_mult=1
    fi
    score_index=0
    tput cup 38 1
    for score_col in {1..43}; do
        if (( ($score_col-1)<$progress_bar )); then
            printf "${score_colours[$colour]}"
            if (( $score_col>21-(${#score}/2) && $score_index<${#score} )); then
                printf "\e[24m${score:$score_index:1}"
                (( score_index++ ))
            else
                printf "\e[4m "
            fi
        else
            printf "${score_colours[$(( colour-1 ))]}"
            if (( $score_col>21-(${#score}/2) && $score_index<${#score} )); then
                printf "\e[24m${score:$score_index:1}"
                (( score_index++ ))
            else
                if (( $colour==1 )); then
                    printf "\e[24m "
                else
                    printf "\e[4m "
                fi
            fi
        fi
    done
    tput sgr0
    (( $score_mult>1 )) && printf '%3sx' "$score_mult" || printf "    "
}

shoot() {
    score_modifier 1
    if [ -n "$2" ]; then
        tput cup 35 $ref_col
        printf " "
        if (( ${print_left[$1]} )); then
            ref_col=${used_cols[$1]}
        else
            ref_col=$2
        fi
        tput cup 35 $ref_col
        printf "${sprite[ship]}"
    fi
    tput cup 34 $ref_col
    printf "${sprite[projectile]}"
    for (( p=33; p>${enemy_row[$1]}; p-- )); do
        tput cup $p $ref_col
        printf "${sprite[projectile]}"
        tput cup $(( $p+1 )) $ref_col
        printf " "
        sleep 0.001
    done
    tput cup $(( $p+1 )) $ref_col
    printf " "
    word="\e[32;1m${words[$word_focus]:0:$match}\e[39m${words[$word_focus]:$match}\e[0m"
    draw_sprites 1 "$word"
}

draw_sprites() {
    if (( $new_level )); then
        tput cup 19 21
        printf "\e[1mLEVEL $level\e[0m"
        sleep 2
        tput cup 19 21
        printf "         "
        new_level=0
        # Clear input buffer
        read -t0.0001 -n 10000 discard
    fi
    if (( $1 )); then
        for (( l=0; l<(${#words[@]}+1); l++ )); do
            if [ -n "$word_focus" ]; then
                if [ -n "$2" ]; then
                    word="$2"
                    l=$word_focus
                else
                    if (( $l==$word_focus )); then
                        if (( ${enemy_row[$l]}>1 && ${enemy_row[$l]}<36 )); then
                            tput cup $(( ${enemy_row[$l]}-1 )) ${enemy_col[$l]}
                            printf "%$(( ${#words[$l]}+2 ))s"
                        fi
                        continue
                    fi
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
            word_len=${#words[$l]}
            pre_row=$(( ${enemy_row[$l]}-1 ))
            (( ${enemy_row[$l]}<1 )) && continue

            if (( ${enemy_row[$l]}==35 && ${used_cols[$l]}==$ref_col )); then
                destroy_enemy 0 $l $pre_row ${enemy_col[$l]}
                destroy_enemy 0 -1 35 $ref_col
                game_over
            fi

            if (( ${enemy_row[$l]}>35 )); then
                if (( ${print_left[$l]} )); then
                    wall_col=${used_cols[$l]}
                else
                    wall_col=${enemy_col[$l]}
                fi
                wall_ind=$(( $wall_col-1 ))
                if (( ${wall_log[$wall_ind]}>0 )); then
                    if (( $word_len<13 )); then
                        wall_kill=$(( ($word_len+2)/3 ))
                    else
                        wall_kill=4
                    fi
                    (( wall_log[$wall_ind]-=$wall_kill ))
                    if (( ${wall_log[$wall_ind]}<1 )); then
                        destroy_wall $wall_col
                    else
                        tput cup 36 $wall_col
                        printf "${sprite[wall${wall_log[$wall_ind]}]}"
                    fi
                    destroy_enemy 0 $l $pre_row ${enemy_col[$l]}
                    (( l-- ))
                    continue
                else
                    tput cup $pre_row ${enemy_col[$l]}
                    printf " "
                    (( ${enemy_row[$l]}==37 )) && game_over
                fi
            fi

            if (( ${enemy_row[$l]}>1 && ${enemy_row[$l]}<36 )); then
                if [ -z "$word_focus" ] || \
                        ( [ -n "$word_focus" ] && (( $l!=$word_focus )) ); then
                    tput cup $pre_row ${enemy_col[$l]}
                    printf "%$(( $word_len+2 ))s"
                fi
                if ! [[ " ${enemy_row[@]} " =~ " $pre_row " ]]; then
                    tput cup $pre_row 1
                    printf '                                               '
                fi
            fi

            tput cup ${enemy_row[$l]} ${enemy_col[$l]}
            if (( ${enemy_row[$l]}>34 )); then
                unset word
                (( ${print_left[$l]} )) && tput cup ${enemy_row[$l]} ${used_cols[$l]}
            fi

            if (( ${print_left[$l]} )); then
                [ -n "$word" ] && printf "$word "
                printf "${enemies[$l]}"
            else
                printf "${enemies[$l]}"
                [ -n "$word" ] && printf " $word"
            fi

            if (( ${enemy_row[-1]}>1 && $RANDOM%3==0 )); then
                if (( $word_len>9 && $word_len<13 )); then
                    load_enemies 2
                elif (( $word_len>12 )); then
                    load_enemies 4
                fi
            fi

            ( [ -n "$word_focus" ] && (( $l==$word_focus )) ) && break
        done
        if [ -n "$match" ] && (( $match==${#words[$word_focus]} )); then
            destroy_enemy 1 $word_focus ${enemy_row[$word_focus]} ${enemy_col[$word_focus]}
        fi
    fi
    [ -n "$2" ] && return
    tput cup 35 $ref_col
    printf "${sprite[ship]}"
}

load_enemies() {
    if [ -z "$1" ]; then
        used_cols=()
        prov_words=( $( sed -n "${level}p" "$text" ) )
    else
        ally_len=$(( $RANDOM%$1+2 ))
        line_max=$( wc -l < "${ally_len}_letters.txt" )
        prov_words=( $(sed -n "$(( $RANDOM%$line_max+1 ))p" "${ally_len}_letters.txt") )
    fi
    for (( i=0, e_row=0; i<${#prov_words[@]}; i++, e_row-- )); do
        word_len=${#prov_words[$i]}
        if (( $word_len>40 )); then
            prov_words=( ${prov_words[@]:0:$i} ${prov_words[@]:$(( $i+1 ))} )
            continue
        fi

        while true; do
            e_col=$(( $RANDOM%46+1 ))
            [[ " ${used_cols[@]} " =~ " $e_col " ]] || break
        done
        if (( $word_len>(46-$e_col) )); then
            enemy_col+=( $(( e_col-($word_len+1) )) )
            print_left+=( 1 )
        else
            enemy_col+=( $e_col )
            print_left+=( 0 )
        fi
        used_cols+=( $e_col )
        enemy_row+=( $e_row )

        if (( $word_len<4 )); then
            enemies+=( "${sprite[enemy1]}" )
        elif (( $word_len<7 )); then
            enemies+=( "${sprite[enemy2]}" )
        elif (( $word_len<10 )); then
            enemies+=( "${sprite[enemy3]}" )
        elif (( $word_len<13 )); then
            enemies+=( "${sprite[boss1]}" )
        elif (( $word_len>12 )); then
            enemies+=( "${sprite[boss2]}" )
        fi
        words+=( "${prov_words[$i]}" )
    done
}

game_loop() {
    while true; do
        # If there are no words left, level up
        if (( ${#words[@]}==0 )); then
            (( level++ ))
            new_level=1
            # Increase speed
            (( $speed>20 )) && (( speed-- ))
            load_enemies
        fi
        draw_sprites $draw_enemies
        pre_time=$( date '+%2N' | sed 's/^0//' )
        read -sn1 -t0.$(( $speed-$time_taken )) key1
        read_pid=$?
        read -sn1 -t0.0001 key2
        read -sn1 -t0.0001 key3
        if (( $read_pid!=142 )); then
            hit=0
            if [[ "$key1" == $'\e' ]]; then
                [ -z "$key2" ] && exit || hit=1
            fi
            key=$( tr 'A-Z' 'a-z' <<< "$key1" )
            [[ "$key" == "" ]] && hit=1
            if [ -z "$word_focus" ]; then
                for (( w=0; w<${#words[@]}; w++ )); do
                    if (( ${enemy_row[$w]}>0 && ${enemy_row[$w]}<35 )); then
                        lower_word=$( tr 'A-Z' 'a-z' <<< "${words[$w]}" )
                        line_of_sight=1
                        if [[ "$key" == "${lower_word:0:1}" ]]; then
                            los_row=${enemy_row[$w]}
                            los_col=${enemy_col[$w]}
                            for (( los_word=0; los_word<${#words[@]}; los_word++ )); do
                                (( $los_word==$w )) && continue
                                if (( ${enemy_col[$los_word]}==$los_col && \
                                        ${enemy_row[$los_word]}>$los_row )); then
                                    line_of_sight=0
                                    break
                                fi
                            done
                            if (( $line_of_sight )); then
                                hit=1
                                match=1
                                word_focus=$w
                                stun=$w
                                shoot $w ${enemy_col[$w]}
                                break
                            fi
                        fi
                    fi
                done
            else
                lower_word=$( tr 'A-Z' 'a-z' <<< "${words[$word_focus]}" )
                if [[ "$key" == "${words[$word_focus]:$match:1}" ]]; then
                    hit=1
                    (( match++ ))
                    stun=$word_focus
                    shoot $word_focus
                fi
            fi
            (( $hit )) || score_modifier 0
        fi
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
            for (( s=0; s<${#words[@]}; s++ )); do
                if [ -n "$stun" ] && [[ "${words[$s]}" == "${words[$stun]}" ]]; then
                    unset stun
                    continue
                fi
                (( enemy_row[$s]++ ))
            done
            draw_enemies=1
            time_taken=0
        fi
    done
}

new_game() {
    # Set blank game variables to allow restarting
    text=/tmp/Superscript/text
    # Format text file to allow each line to be built into an array
    tr '.' '\n' < "$text_file" | sed -r 's/(-|—)/ /;s/[^([:alnum:]| )]//g;/^ *$/d' >| "$text"
    clear_map 37
    tput cup 36 1
    # Build wall
    wall_log=()
    for (( b=0; b<47; b++ )); do
        printf "${sprite[wall4]}"
        wall_log+=( 4 )
    done
    # Set level to 0 and then instantly level up
    level=0
    new_level=1
    speed=61
    ref_col=24
    # Set draw enemies to numeric true
    draw_enemies=1
    # Reset time
    time_taken=0
    score=0
    # Rainbow from red to purple
    score_colours=( '\e[0m' '\e[38;5;160m' '\e[38;5;202m' '\e[38;5;214m' \
        '\e[38;5;76m' '\e[38;5;86m' '\e[38;5;27m' '\e[38;5;129m' )
    colour=1
    score_mult=1
    progress_bar=0
    overall_progress=0
    game_loop
}

show_scores() {
    return
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
    printf '└───────────────────────────────────────────────┘'
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
    printf '\e[1mS U P E R S C R I P T\e[0m'
    tput cup 10 20
    printf '\e[1mCONTROLS\e[0m'
    tput cup 14 11
    echo 'Ctrl-C       -       Quit'
    selected=3
    # Get/Create current high score
    hs_log=/home/$USER/.superscript_highscore
    [ -s "$hs_log" ] || echo "0" >| $hs_log
    high_score=$( < $hs_log )
    text_file=text.txt
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
        printf "$START"
        tput cup 20 19
        printf "$SCORES"
        tput cup 22 19
        printf "$TEXT"
        tput cup 24 22
        printf "$QUIT"
        # Get user input and control keys
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

# Populate sprite array
declare -A sprite
sprites

stty -echo # Disable echo
main_menu
