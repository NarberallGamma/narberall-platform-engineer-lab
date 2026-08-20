#!/bin/bash
# build /etc/ansible/hosts groups from ~/.ssh/config (Host lines after ### START ###)

ANSIBLE_HOSTS=~/.ssh/ansible_hosts
echo > ${ANSIBLE_HOSTS}

ALL_HOSTS=`cat ~/.ssh/config | sed '1,/^### START ###$/d' | grep ^Host | sort | uniq | awk '{print $2}' | grep -v modem | grep -v '\*'`

PROJECTS=`echo "${ALL_HOSTS}" | awk -F  "." '{print $1}' | sort | uniq`

for PROJECT in ${PROJECTS}
do
  echo "[$PROJECT]" >> ${ANSIBLE_HOSTS}
  echo >> ${ANSIBLE_HOSTS}
  echo "$ALL_HOSTS" | grep "^${PROJECT}\." >> ${ANSIBLE_HOSTS}
  echo >> ${ANSIBLE_HOSTS}
  echo >> ${ANSIBLE_HOSTS}
done

sudo cp /etc/ansible/hosts /etc/ansible/hosts.bak
cat ${ANSIBLE_HOSTS} | sudo tee /etc/ansible/hosts

echo "Done!"
