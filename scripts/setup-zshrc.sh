#!/bin/bash

if [ -f ~/.zshrc ]; then
cat << EOF >> ~/.zshrc

alias l='ls -CF'
alias la='ls -A'
alias ll='ls -alF'
alias ls='ls --color=auto'

alias tf='terraform \$*'
alias tfi='terraform init \$*'
alias tff='terraform fmt -recursive'
alias tfv='terraform validate'
alias tfp='terraform plan \$*'
alias tfa='terraform apply \$*'
alias tfd='terraform destroy \$*'
alias tfo='terraform output'

alias k='kubectl \$*'
alias ka='kubectl apply \$*'
alias kd='kubectl describe \$*'
alias kg='kubectl get \$*'
alias kl='kubectl logs \$*'
alias kr='kubectl run \$*'

EOF
fi
