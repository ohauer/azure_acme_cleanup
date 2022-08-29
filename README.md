# azure_acme_cleanup
Script to cleanup orphaned acme records (e.g. leftovers from ansible or any other acme DNS tools)

Have you ever done a acme record cleanup via the azure DNS webUI?

If yes, this script will help to save nerves, life is too short to cleanup orphaned acme records with this crappy DNS webUI!

## set the following variables in file ./azenv or as environment vars to your values
- RESOURCE_GROUP
- ZONE_NAME
- SUBSCRIPTION

For example:

```sh
cat > ./azenv << EOM
# ============================
# vars azure zone
RESOURCE_GROUP=my-azure-dns-resource-group
ZONE_NAME=example.net
SUBSCRIPTION=MYSUBSCRIPTION
EOM

or depending on your shell use setenv or export VAR=VALUE
```

## cleanup procedure
1. run the script [azure_acme_cleanup.sh](azure_acme_cleanup.sh) on a system with docker installed and access to the internet

```sh
./azure_acme_cleanup.sh -r
```

A shell will be opened inside the container

3. use command /cleanup.sh and follow the instructions

   the script cleanup.sh will create a shell script with instructions to delete orphaned acme records

```sh
bash# ./cleanup.sh
running inside
==============================================================================

    usage: /cleanup [-d|-e|-g]
        -e show azure related vars
        -d delete all DNS TXT records containing _acme
        -g generate list and script with DNS TXT record names containing _acme

==============================================================================

bash# /cleanup -g
running inside
To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code %%RANDOM_TOKEN%% to authenticate.
```

4. open the page https://microsoft.com/devicelogin in a browser and add the %%RANDOM_TOKEN%%

   The script will continue as soon you login to azure with your account and will create the script /root/delete_acme_txt_records.sh

5. use command /cleanup.sh -d to delete orphaned acme records

```sh
bash# /cleanup -d
```

6. after cleanup exit the container, the container will be removed automatically


