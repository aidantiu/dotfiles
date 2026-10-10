# General aliases
alias cls="clear"
alias home="cd ~/"
alias dl="cd ~/Downloads"
alias ax="cd ~/Documents/axon"
alias fr="cd ~/Documents/freelance"

# fan control
alias fan="sudo service fancontrol start"

# Start arduino
alias ard='~/Downloads/"arduino-ide_2.3.8_Linux_64bit(1).AppImage" --no-sandbox &'

# find pi
alias scanpi='sudo nmap -sn 192.168.31.0/24'


# homelab
alias wake='cd /home/hiraya/Documents/homelab/homelab-ansible && ansible-playbook playbooks/wake_mode.yml -e '\''{"wake_start_docker_services": true, "allow_wake_without_policy": true, "wake_confirm": true}'\'''


