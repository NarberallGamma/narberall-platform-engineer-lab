echo '
{
'
for i in `cat 1`; do
echo
#echo "      - name: $(echo $i|cut -f1 -d '@')"
#echo "        pass: \"{{ lookup('hashi_vault', 'secret=secret/data/postgres:$(echo $i|cut -f1 -d '@')') }}\""
echo '"'$(echo $i|cut -f1 -d '@')'": "'$(pwgen -1 70 -syB --remove-chars=\'\"\\\/)'",'

done
echo ',"a": "a"}'
