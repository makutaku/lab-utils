# This is my current / up-to-date list of bash aliases.
# This is the exact same file that is on all of my hosts - synced using Synthing.

# Rename shared/config/bash_aliases.env.example and use it as a starter

# SOURCE ENVIRONMENTAL VARIABLES FOR BASH_ALIASES
#if [[ -f "$REPO/shared/config/bash_aliases.env" ]]; then
#  source $REPO/shared/config/bash_aliases.env 
#fi 

# CHANGE TO CUSTOM BASH PROMPT
username=$USER
export PS1="\[\e[0;32m\]\u\[\e[0m\]@\[\e[0;33m\]\H\[\e[0m\]:\[\e[0;36m\]\w\[\e[0m\]\$ "


# DOCKER - All Docker commands start with "d" AND Docker Compose commands start with "dc"
alias dstop='sudo docker stop $(sudo docker ps -a -q)' # usage: dstop container_name
alias dstopall='sudo docker stop $(sudo docker ps -aq)' # stop all containers
alias drm='sudo docker rm $(sudo docker ps -a -q)' # usage: drm container_name
alias dprunevol='sudo docker volume prune' # remove unused volumes
alias dprunesys='sudo docker system prune -a' # remove unsed docker data
alias ddelimages='sudo docker rmi $(sudo docker images -q)' # remove unused docker images
alias derase='dstopcont ; drmcont ; ddelimages ; dvolprune ; dsysprune' # WARNING: removes everything! 
alias dprune='ddelimages ; dprunevol ; dprunesys' # remove unused data, volumes, and images (perfect for safe clean up)
alias dexec='sudo docker exec -ti' # usage: dexec container_name (to access container terminal)
alias dps='sudo docker ps -a' # running docker processes
alias dpss='sudo docker ps -a --format "table {{.Names}}\t{{.State}}\t{{.Status}}\t{{.Image}}" | (sed -u 1q; sort)' # running docker processes as nicer table
alias ddf='sudo docker system df' # docker data usage (/var/lib/docker)
alias dlogs='sudo docker logs -tf --tail="50" ' # usage: dlogs container_name
alias dlogsize='sudo du -ch $(sudo docker inspect --format='{{.LogPath}}' $(sudo docker ps -qa)) | sort -h' # see the size of docker containers
alias dips="sudo docker ps -q | xargs -n 1 sudo docker inspect -f '{{.Name}}%tab%{{range .NetworkSettings.Networks}}{{.IPAddress}}%tab%{{end}}' | sed 's#%tab%#\t#g' | sed 's#/##g' | sort | column -t -N NAME,IP\(s\) -o $'\t'"

alias dp600='sudo chown -R root:root $REPO/secrets ; sudo chmod -R 600 $REPO/secrets ; sudo chown -R root:root $REPO/.env ; sudo chmod -R 600 $REPO/.env' # re-lock permissions
alias dp777='sudo chown -R $USER:$USER $REPO/secrets ; sudo chmod -R 777 $REPO/secrets ; sudo chown -R $USER:$USER $REPO/.env ; sudo chmod -R 777 $REPO/.env' # open permissions for editing

# DOCKER COMPOSE TRAEFIK 2 - All docker-compose commands start with "dc" 
case $HOSTNAME in
    ds918) # synology at this point uses an old version of docker. Therefore, 'docker-compose' instead of 'docker compose'
      alias dcrun='sudo docker-compose -f $REPO/docker-compose-$HOSTNAME.yml' # /volume1/docker symlinked to /var/services/homes/user/docker
      ;;
    *)
      alias dcrun='sudo docker compose --profile all -f $REPO/docker-compose-$HOSTNAME.yml'
      ;;
esac

alias dclogs='dcrun logs -tf --tail="50" ' # usage: dclogs container_name
alias dcup='dcrun up -d --build --remove-orphans' # up the stack
alias dcdown='dcrun down --remove-orphans' # down the stack
alias dcrec='dcrun up -d --force-recreate --remove-orphans' # usage: dcrec container_name
alias dcstop='dcrun stop' # usage: dcstop container_name
alias dcrestart='dcrun restart ' # usage: dcrestart container_name
alias dcstart='dcrun start ' # usage: dcstart container_name
alias dcpull='dcrun pull' # usage: dcpull to pull all new images or dcpull container_name
alias traefiklogs='tail -f $REPO/logs/$HOSTNAME/traefik/traefik.log' # tail traefik logs

# Manage "core" services as defined by profiles in docker compose
alias startcore='sudo docker compose --profile core -f $REPO/docker-compose-$HOSTNAME.yml start'
alias createcore='sudo docker compose --profile core -f $REPO/docker-compose-$HOSTNAME.yml up -d --build --remove-orphans'
alias stopcore='sudo docker compose --profile core -f $REPO/docker-compose-$HOSTNAME.yml stop'
# Manage "media" services as defined by profiles in docker compose
alias stopmedia='sudo docker compose --profile media -f $REPO/docker-compose-$HOSTNAME.yml stop'
alias createmedia='sudo docker compose --profile media -f $REPO/docker-compose-$HOSTNAME.yml up -d --build --remove-orphans'
alias startmedia='sudo docker compose --profile media -f $REPO/docker-compose-$HOSTNAME.yml start'
# Manage "diwkiads" services as defined by profiles in docker compose
alias stopdownloads='sudo docker compose --profile downloads -f $REPO/docker-compose-$HOSTNAME.yml stop'
alias createdownloads='sudo docker compose --profile downloads -f $REPO/docker-compose-$HOSTNAME.yml up -d --build --remove-orphans'
alias startdownloads='sudo docker compose --profile downloads -f $REPO/docker-compose-$HOSTNAME.yml start'
# Manage Starr apps as defined by profiles in docker compose
alias stoparrs='sudo docker compose --profile arrs -f $REPO/docker-compose-$HOSTNAME.yml stop'
alias startarrs='sudo docker compose --profile arrs -f $REPO/docker-compose-$HOSTNAME.yml start'
alias createarrs='sudo docker compose --profile arrs -f $REPO/docker-compose-$HOSTNAME.yml up -d --build --remove-orphans'
# Manage "dbs" (database) services as defined by profiles in docker compose
alias stopdbs='sudo docker compose --profile dbs -f $REPO/docker-compose-$HOSTNAME.yml stop'
alias createdbs='sudo docker compose --profile dbs -f $REPO/docker-compose-$HOSTNAME.yml up -d --build --remove-orphans'
alias startdbs='sudo docker compose --profile dbs -f $REPO/docker-compose-$HOSTNAME.yml start'

# CROWDSEC
alias cscli='dcrun exec -t crowdsec cscli'
alias csdecisions='cscli decisions list'
alias csalerts='cscli alerts list'
alias csinspect='cscli alerts inspect -d'
alias cshubs='cscli hub list'
alias csparsers='cscli parsers list'
alias cscollections='cscli collections list'
alias cshubupdate='cscli hub update'
alias cshubupgrade='cscli hub update'
alias csmetrics='cscli metrics'
alias csmachines='cscli machines list'
alias csbouncers='cscli bouncers list'
alias csfbstatus='sudo systemctl status crowdsec-firewall-bouncer.service'
alias csfbstart='sudo systemctl start crowdsec-firewall-bouncer.service'
alias csfbstop='sudo systemctl stop crowdsec-firewall-bouncer.service'
alias csfbrestart='sudo systemctl restart crowdsec-firewall-bouncer.service'
alias tailkern='sudo tail -f /var/log/kern.log'
alias tailauth='sudo tail -f /var/log/auth.log'
alias tailcsfb='sudo tail -f /var/log/crowdsec-firewall-bouncer.log'
alias csbrestart='dcrec2 traefik-bouncer ; csfbrestart'

# WEB STACK
alias webrs='dcrec php7 redis nginx'

# DOCKER TRAEFIK 1 SWARM
alias dslogs='sudo docker service logs -tf --tail="50"'
alias dsps='sudo docker stack ps zstack'
alias dsse='sudo docker stack services zstack'
alias dsls='sudo docker stack ls'
alias dsrm='sudo docker stack rm'
alias dsup='sudo docker stack deploy --compose-file $REPO/docker-compose-swarm.yml zstack'
alias dshelp='echo "dslogs dsps dsse dsls dsrm dsup"'

# COMPRESSION
alias untargz='tar --same-owner -zxvf'
alias untarbz='tar --same-owner -xjvf'
alias lstargz='tar -ztvf'
alias lstarbz='tar -jtvf'
alias targz='tar -zcvf'
alias tarbz='tar -cjvf'

# NAVIGATION
alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'

# SYNC AND COPY
alias scp='scp -r'
alias rsynce='sudo rsync -avzh --progress --force --delete --exclude-from $REPO/shared/config/rsync-exclude'
alias rsyncne='sudo rsync -avzh --progress --force --delete'
alias cp='cp --verbose' # native copy
alias cpx='sudo rsync -avzh --info=progress2' # copy files with rsync
alias mv='mv --verbose' # native move
alias mvx='sudo rsync -avzh --info=progress2 --remove-source-files' # move files with rsync

# SEARCH AND FIND
alias gh='history|grep' # search bash history
alias findr='sudo find / -name'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# TRASH - trash-cli
#alias rm='trash-put'
#alias rmv='rm -rv'
#alias tempty='trash-empty ; sudo trash-empty ; sudo -H trash-empty'
#alias tlist='trash-list'
#alias srmt='sudo trash-put'

# FILE SIZE AND STORAGE
alias fdisk='sudo fdisk -l'
alias uuid='sudo vol_id -u'
alias ls='ls -F --color=auto --group-directories-first'
alias ll='ls -alh --color=auto --group-directories-first'
alias lt='ls --human-readable --color=auto --size -1 -S --classify' # file size sorted
alias lsr='ls --color=auto -t -1' # recently modified
alias mnt='mount | grep -E ^/dev | column -t' # show mounted drives
alias dirsize='sudo du -hx --max-depth=1'
alias dirusage='du -ch | grep total' # Grabs the disk usage in the current directory
alias diskusage='df -hl --total | grep total' # Gets the total disk usage on your machine
alias partusage='df -hlT --exclude-type=tmpfs --exclude-type=devtmpfs' # Shows the individual partition usages without the temporary memory values
alias usage10='du -hsx * | sort -rh | head -10' # Gives you what is using the most space. Both directories and files. Varies on current directory

# BASH ALIASES
alias baupdate='. ~/.bashrc'
alias baedit='nano $HOME/.bash_aliases'
alias bacopy='sudo cp $HOME/.bash_aliases* /root/'
alias baget='curl -s https://raw.githubusercontent.com/htpcBeginner/docker-traefik/master/shared/config/bash_aliases -o /$HOME/.bash_aliases >/dev/null 2>&1'

# GIT AND SITE MANAGEMENT
alias gcpush='echo "Usage: gcpush ../commits/date.txt" ; cd $REPO ; bash scripts/github/doccheck.sh' # To push my files to docker-traefik repo
alias gpush='cd $REPO ; git push'
alias ggraph='git log --all --decorate --oneline --graph'
alias gits='git status'

# MAIL SERVER TESTING
alias nullsend='sudo echo 1 > /var/spool/nullmailer/trigger'
alias tmail1='echo -e "### `date +'\''%Y-%m-%d %H:%M'\''` ### \n\n This is a mail server test using tmail1 alias." | mail -s "tmail1 from $HOSTNAME" info@$PRIMARY_DOMAIN -aFrom:$HOSTNAME@$PRIMARY_DOMAIN'
alias tmail2='echo -e "### `date +'\''%Y-%m-%d %H:%M'\''` ### \n\n This is a mail server test using tmail2 alias. It needs and email id after the tmail2 command." | mail -s "tmail2 from $HOSTNAME"'

# UFW FIREWALL
alias ufwenable='sudo ufw enable'
alias ufwdisable='sudo ufw disable'
alias ufwallow='sudo ufw allow'
alias ufwlimit='sudo ufw limit'
alias ufwlist='sudo ufw status numbered'
alias ufwdelete='sudo ufw delete'
alias ufwreload='sudo ufw reload'

# SYSTEMD START, STOP AND RESTART
alias ctlreload='sudo systemctl daemon-reload'
alias ctlstart='sudo systemctl start'
alias ctlstop='sudo systemctl stop'
alias ctlrestart='sudo systemctl restart'
alias ctlstatus='sudo systemctl status'
alias ctlenable='sudo systemctl enable'
alias ctldisable='sudo systemctl disable'
alias ctlactive='sudo systemctl is-active'

alias shellstart='ctlstart shellinabox'
alias shellstop='ctlstop shellinabox'
alias shellrestart='ctlrestart shellinabox'
alias shellstatus='ctlstatus shellinabox'

alias sshstart='ctlstart ssh'
alias sshstop='ctlstop ssh'
alias sshrestart='ctlrestart ssh'
alias sshstatus='ctlstatus ssh'

alias ufwstart='ctlstart ufw'
alias ufwstop='ctlstop ufw'
alias ufwrestart='ctlrestart ufw'
alias ufwstatus='ctlstatus ufw'

alias webminstart='ctlstart webmin'
alias webminstop='ctlstop webmin'
alias webminrestart='ctlrestart webmin'
alias webminstatus='ctlstatus webmin'

alias sambastart='ctlstart smbd'
alias sambastop='ctlstop smbd'
alias sambarestart='ctlrestart smbd'
alias sambastatus='ctlstatus smbd'

alias nfsstart='ctlstart nfs-kernel-server'
alias nfsstop='ctlstop nfs-kernel-server'
alias nfsrestart='ctlrestart nfs-kernel-server'
alias nfsstatus='ctlstatus nfs-kernel-server'
alias nfsreload='sudo exportfs -a'

# INSTALLATION AND UPGRADE
alias update='sudo apt-get update'
alias upgrade='sudo apt-get update && sudo apt-get upgrade'
alias install='sudo apt-get install'
alias finstall='sudo apt-get -f install'
alias rinstall='sudo apt-get -f install --reinstall'
alias uninstall='sudo apt-get remove'
alias search='sudo apt-cache search'
alias addkey='sudo apt-key adv --recv-keys --keyserver keyserver.ubuntu.com'

# CLEANING
alias clean='sudo apt-get clean && sudo apt-get autoclean'
alias remove='sudo apt-get remove && sudo apt-get autoremove'
alias purge='sudo apt-get purge'
alias deborphan='sudo deborphan | xargs sudo apt-get -y remove --purge'
alias cleanall='clean && remove && deborphan && purge'

# SHUTDOWN AND RESTART
alias shutdown='sudo shutdown -h now'
alias reboot='sudo reboot'
alias poweroff='sudo poweroff'

# NETWORKING
alias portsused='sudo netstat -tulpn | grep LISTEN'
alias showports='netstat -lnptu'
alias showlistening='lsof -i -n | egrep "COMMAND|LISTEN"'
alias ping='ping -c 5'
alias ipe='curl ipinfo.io/ip' # external ip
alias ipi='ipconfig getifaddr en0' # internal ip
alias header='curl -I' # get web server headers 

# SYNOLOGY DSM COMMANDS
alias servicelist='sudo synoservicecfg --list' # does not work in DSM 7
alias servicestatus='sudo synosystemctl status'
alias servicestop='sudo synosystemctl stop'
alias servicehstop='sudo synoservicecfg --hard-stop' # does not work in DSM 7
alias servicestart='sudo synosystemctl start'
alias servicehstart='sudo synoservicecfg --hard-start' # does not work in DSM 7
alias servicerestart='sudo synosystemctl restart'
alias restartdocker='sudo synosystemctl restart pkgctl-Docker'

# MISCELLANEOUS
alias wget='wget -c'
alias nano='sudo nano -iSw$'
alias scxterm='bash $REPO/scripts/xterm.sh'

# SYSTEM MONITORING
alias meminfo='free -m -l -t' # memory usage
alias psmem='ps auxf | sort -nr -k 4' # get top process eating memory
alias psmem10='ps auxf | sort -nr -k 4 | head -10' # get top process eating memory
alias pscpu='ps auxf | sort -nr -k 3' # get top process eating cpu
alias pscpu10='ps auxf | sort -nr -k 3 | head -10' # get top process eating cpu
alias cpuinfo='lscpu' # Get server cpu info
alias gpumeminfo='grep -i --color memory /var/log/Xorg.0.log' # get GPU ram on desktop / laptop
alias free='free -h'

# RCLONE
alias rcdlogs='tail -f $REPO/logs/cloudserver/rclone-drive.log'
alias rcclogs='tail -f $REPO/logs/cloudserver/rclone-crypt.log'
alias rcupmedia='bash $REPO/scripts/cloudserver/upload-media-now.sh'
alias rcupmedialogs='tail -f $REPO/logs/cloudserver/upload-media-now.log'
alias rcupdump='bash $REPO/scripts/cloudserver/upload-dump.sh'
alias rcupdumplogs='tail -f $REPO/logs/cloudserver/upload-dump.log'
alias rcrestart='sudo bash $REPO/scripts/rclone-restart.sh'
alias rcstop='sudo bash $REPO/scripts/rclone-stop.sh'
alias rcstart='sudo bash $REPO/scripts/rclone-start.sh'
alias rcstatus='sudo bash $REPO/scripts/rclone-status.sh'
alias rcps="ps -ef | grep '/usr/bin/rclone sync\|/usr/bin/rclone copy\|/usr/bin/rclone move'" # see running rclone copy sync or move
alias rcupdate="sudo -v ; curl https://rclone.org/install.sh | sudo bash" # update rclone
alias rcpurge="kill -SIGHUP $(pidof rclone)" # purge rclone cache
alias rcforget="rclone rc vfs/forget" # rclone forget via remote control

# YT-DLP
#alias ytupdate='yt-dlp -U'
#alias ytlist='yt-dlp --list-formats'
#alias ytdump='yt-dlp --dump-json'
#alias ytdv='yt-dlp --config-location $REPO/appdata/yt-dlp/yt-dlp-video.conf'
#alias ytdvc='yt-dlp --cookies "$REPO/appdata/yt-dlp/cookies.txt" --config-location $REPO/appdata/yt-dlp/yt-dlp-video.conf'
#alias ytda='yt-dlp --config-location $REPO/appdata/yt-dlp/yt-dlp-audio.conf'
#alias ytdac='yt-dlp --cookies "$REPO/appdata/yt-dlp/cookies.txt" --config-location $REPO/appdata/yt-dlp/yt-dlp-audio.conf'

# Auto-Traefik
alias sshagent='eval "$(ssh-agent -s)" ; ssh-add $HOME/auto-traefik/.git/auto_traefik_github'
alias atpush='sshagent ; git add -A ; git commit -m "updates" ; git push'

# PiHole
alias pidis='bash $HOME/server/scripts/pihole-disable.sh'
alias pien='bash $HOME/server/scripts/pihole-enable.sh'
alias pi10='bash $HOME/server/scripts/pihole-10.sh'
alias piup='bash $HOME/server/scripts/pihole-update.sh'
alias rpi3up='bash $HOME/server/scripts/rpi3-update.sh'
alias rpi0up='bash $HOME/server/scripts/rpi0-update.sh'

# VNC
alias vnc1='vncserver -geometry 1270x720 -depth 24'
alias vnckill1='vncserver -kill :1'

#############################################################################################

## AK
alias genpass='openssl rand -base64 24 | tr -d "/+=" | head -c32 && echo'
export HOSTNAME=$(hostname)
export LAB_STACKS='/opt/lab-stacks'
export LAB_UTILS="$HOME/lab-utils"
alias ak-backup='$LAB_UTILS/file-system/backup.sh'
alias ak-restore='$LAB_UTILS/file-system/restore.sh'
alias ak-clone-repo='$LAB_UTILS/git/clone-repo.sh'
alias ak-restart-docker='sudo systemctl restart docker'
alias ak-backup-vol='$LAB_UTILS/docker/backup-volume.sh'
alias ak-restore-vol='$LAB_UTILS/docker/restore-volume.sh'
alias ak-relocate-data='$LAB_UTILS/file-system/relocate-data.sh'
alias ak-colocate-data='$LAB_UTILS/file-system/colocate-data.sh'
alias ak-clone-vol='$LAB_UTILS/docker/clone-volume.sh'
alias ak-link-vols='$LAB_UTILS/docker/link-volumes.sh'
alias ak-harvester-up='sudo $LAB_STACKS/deploy-stacks.sh up $LAB_STACKS/harvester.manifest'
alias ak-harvester-down='sudo $LAB_STACKS/deploy-stacks.sh down $LAB_STACKS/harvester.manifest'
alias ak-gateway-up='sudo $LAB_STACKS/deploy-stacks.sh up $LAB_STACKS/gateway.manifest'
alias ak-gateway-down='sudo $LAB_STACKS/deploy-stacks.sh down $LAB_STACKS/gateway.manifest'
alias ak-home-gateway-up='sudo $LAB_STACKS/deploy-stacks.sh up $LAB_STACKS/home-gateway.manifest'
alias ak-home-gateway-down='sudo $LAB_STACKS/deploy-stacks.sh down $LAB_STACKS/home-gateway.manifest'
alias ak-nextcloud-up='sudo $LAB_STACKS/deploy-stacks.sh up $LAB_STACKS/nextcloud.manifest'
alias ak-nextcloud-down='sudo $LAB_STACKS/deploy-stacks.sh down $LAB_STACKS/nextcloud.manifest'
alias ak-netops-up='sudo $LAB_STACKS/deploy-stacks.sh up $LAB_STACKS/netops.manifest'
alias ak-netops-down='sudo $LAB_STACKS/deploy-stacks.sh down $LAB_STACKS/netops.manifest'
alias ak-dev-up='sudo $LAB_STACKS/deploy-stacks.sh up $LAB_STACKS/dev.manifest'
alias ak-dev-down='sudo $LAB_STACKS/deploy-stacks.sh down $LAB_STACKS/dev.manifest'

