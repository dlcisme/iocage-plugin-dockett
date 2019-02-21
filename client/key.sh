#!/usr/local/bin/bash 

echo $HOSTNAME


   # set the SSH user
#SSH="sshuser@ssh2"
SSH="dockett@192.168.0.180"
   # set the SSH port
PORT="22"


_KEY_COMMENT="Dana's Key"
_KEY_NAME="id_ed25519"



# create the key ssh key if it doesn't exist
if [ ! -f ~/.ssh/id_ed25519.pub ]; then
  echo "Creating SSH key"
  ssh-keygen -t ed25519 -f ~/.ssh/"$_KEY_NAME" -C "$_KEY_COMMENT"
fi
  echo "Copying key to server"
  cat ~/.ssh/"$_KEY_NAME.pub" | ssh -p $PORT $SSH "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >>  ~/.ssh/authorized_keys"

# setup config file so user can no longer login in with password
# NOTE: each user must be set up on their own and have their own password
# /etc/ssh/sshd_config
# Host *
#   ChallengeResponseAuthentication no  
