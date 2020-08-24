# Generates a thick line for the main banners, detects terminal width at creation
function line {
  local ncol=$(tput cols)
  local count=2
  printf "+"
  while [[ ${count} -lt ${ncol} ]]; do
      printf "="
      let count++
    done
  printf "+\n"
}

# Generates a thin line for secondary banners, detects terminal width at creation
function subline {
  local ncol=$(tput cols)
  local count=2
  printf "+"
  while [[ $count -lt $ncol ]]; do
      printf "-"
      let count++
    done
  printf "+\n"
}

# Generates a special frame for error banners, detects terminal width at creation
function errline {
  local ncol=$(tput cols)
  local count=6
  printf "!!>"
  while [[ $count -lt $ncol ]]; do
     printf "-"
     let count++
    done
  printf "<!!\n"
}

# Just a blank line: yes, I'm lazy this way.
function blankline {
  echo ""
}

# Takes in a text input and writes it on stdout, centered in respect to the terminal
function ctext() {
  local text="$1"
  local tlen=${#text} # the number of characthers of text
  local ncol=$(tput cols)
  local head=$(( (${tlen} + ${ncol} - 1)/2 ))
  local tail=$(( (${ncol} - ${tlen})/2 ))
  printf "|%*s" $head "$text"
  printf "%*s\n" $tail "|"
}

line
blankline
subline
blankline
errline
blankline
ctext "caio"
blankline
blankline

function print_title(){
    line
    ctext "$*"
    line
}

print_title "this is a title"
blankline

function print_subtitle(){
    subline
    ctext "$*"
    subline
}

print_subtitle "this is a subtitle"
blankline

function print_error(){
    errline
    ctext "$*"
    errline
}

print_error "this is an error"
blankline
