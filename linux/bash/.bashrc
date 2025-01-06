# always just manually add these to the .bashrc
# and keep the rest of the original bashrc intact
if [ -f ~/.bash_aliases ]; then
    source ~/.bash_aliases
fi

if [ -f ~/.bash_local ]; then
    source ~/.bash_local
fi