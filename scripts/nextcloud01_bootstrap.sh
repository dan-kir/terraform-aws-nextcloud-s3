#!/bin/bash
hostnamectl set-hostname nextcloud01
echo "export PS1='\[\e[37m\][\[\e[m\]\[\e[30;44m\]\u\[\e[m\]\[\e[37m\]@\[\e[m\]\[\e[34;40m\]\h\[\e[m\] \[\e[32m\]\w\[\e[m\]\[\e[37m\]]\[\e[m\]\[\e[34m\]\$\[\e[m\] '" >> /home/admin/.bashrc
## Create hashed password using - openssl passwd -1 -salt {salt_here} {password_here}
usermod --password '$1$salt_here$UQMBxUpQX3/cXzAWQMp.Z1' root
usermod --password '$1$salt_here$UQMBxUpQX3/cXzAWQMp.Z1' admin
