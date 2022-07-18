## Must have flyctl installed and be logged in to fly
set -e

echo "What is the organization name on Fly (not including -dev or -prod)?"
read base_name

START_TIME=$(date +%s)

for env in dev prod; do
    ## ORG
    ORG_NAME="$base_name-$env"
    echo "Setting up $ORG_NAME"

    ## APP
    if [ "$env" = "prod" ]; then
        echo "You will be prompted WARN app flag 'sampleapptest-dev' does not match app name in config file 'sampleapptest'. Press y"
    fi
    fly apps create --name $ORG_NAME -o $ORG_NAME
    echo "Created app $ORG_NAME in $ORG_NAME"
    DJANGO_SECRET_KEY=`python -c 'import random; print("".join([random.choice("abcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*(-_=+)") for i in range(50)]))'`
    echo "DJANGO_SECRET_KEY=$DJANGO_SECRET_KEY"
    fly secrets set DJANGO_SECRET_KEY="$DJANGO_SECRET_KEY" -a $ORG_NAME
    echo "Set DJANGO_SECRET_KEY"

    ## POSTGRES
    POSTGRES_NAME="$ORG_NAME-postgres"
    flyctl postgres create \
        --organization $ORG_NAME \
        --name $POSTGRES_NAME \
        --region ord \
        --vm-size shared-cpu-1x \
        --volume-size 1 \
        --initial-cluster-size 1
    echo "Created postgres $POSTGRES_NAME in $ORG_NAME"
    fly postgres attach -a $ORG_NAME --postgres-app $POSTGRES_NAME
    echo "Attached $POSTGRES_NAME"

    ## REDIS
    ## verify that a directory called redis with fly.toml exists before running
    cd redis
    REDIS_NAME="$ORG_NAME-redis"
    fly apps create --name $REDIS_NAME --org $ORG_NAME
    fly volumes create redis_server --size 1 -r ord
    REDIS_PASSWORD=`python -c 'import random; print("".join([random.choice("abcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*(-_=+)") for i in range(50)]))'`
    echo "REDIS_PASSWORD: $REDIS_PASSWORD"
    fly secrets set REDIS_PASSWORD="$REDIS_PASSWORD"
    fly deploy -a $REDIS_NAME -r ord
    echo "Deployed $REDIS_NAME"

    cd ..
    
    fly secrets set REDIS_PASSWORD="$REDIS_PASSWORD"

    fly deploy -a $ORG_NAME -r ord
    echo "Deployed $ORG_NAME"
done

END_TIME=$(date +%s)
echo "It took $(($END_TIME - $START_TIME)) seconds to set up fly"