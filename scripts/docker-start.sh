NAME="$(basename $PWD)"-$RANDOM

[ ! -d "$(pwd)/.config" ] && mkdir $(pwd)/.config
[ ! -d "$(pwd)/.ssh" ] && mkdir $(pwd)/.ssh
[ ! -f "$(pwd)/.terraformrc" ] && touch $(pwd)/.terraformrc

echo "Starting container - $NAME"
docker run -ti --rm \
    -v "$(pwd)"/.config:/root/.config \
    -v "$(pwd)"/.ssh:/root/.ssh \
    -v "$(pwd)"/.terraformrc:/root/.terraformrc \
    -v "$(pwd)":/work \
    -w /work \
    --name $NAME \
    gcp-devops

