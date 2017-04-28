# $1 is resource group name
# $2 is the password
mkdir .ocpazure
cd .ocpazure
azure login
azure account show >> account.out
azure ad sp create -n $1 -p Pass@word1 --home-page http://${1}web --identifier-uris http://${1}web >> sp.out
azure role assignment create --objectId ff863613-e5e2-4a6b-af07-fff6f2de3f4e -o Reader -c /subscriptions/{subscriptionId}/



