#!/bin/bash
#
# Initial Script
# Powered By TSMX AIX - DL TSMX AIX 
# By betobetoman
#
#

os=$(uname -s) 
if [[ $os == "Linux" ]]; then
	echo "Starting User Review" 
else
	echo "User Review should be executed on linux server"; exit 1
fi
files=$(ls *_passwd | wc -l) 
if [ $files -gt 0 ]; then
	echo "Processing Files" 
else
	echo "There are no files for processing, remember to have hostname_passwd, hostname_group, hostname_sudoers"; exit 2
fi 

ls exclusions 2>/dev/null
if [ $? = 0 ]; then
	echo "The exclusions file exists!" 
else
	echo "The exclusions file does not exist, creating ..." 
	echo  -e "root \ndaemon \nbin \nsys \nadm \nuucp \nnobody \nlpd \nlp \ninvscout \nsnapp \nipsec \nsshd" > exclusions
fi

> hosts_temp
> hosts_process
ls *_passwd >> hosts_temp
cat hosts_temp | awk -F_ '{print $1}' > hosts_process 
nhosts=$(cat hosts_process | wc -l)
rm hosts_temp

#Checking if files are complete. 
for server in $(echo $hosts)
do
	archs=$(ls -l $server* | wc -l)
	if [ $archs == 3 ]; then 
		echo "Files are complete for host $server" 
	else
		echo "Files are missing for host $server"; exit 3 
	fi
done

#Start procesing files to get users info
> user_review
header=$(sed 's/ /:/g' <<< "$(cat hosts_process|xargs)")
users=$(cat *_passwd | awk -F: '{print $1}' | sort -n | uniq)
echo "USERID:$header" >> user_review
for user in $(echo $users)
do
	echo "$user":"" >> user_review
done
for host in $(cat hosts_process)
do 
	echo "Processing host $host for user review ..."
	for user in $(echo $users)
	do
		exist=$(cat $host"_passwd" | grep ^"$user"":" | wc -l)
		if [ $exist -gt 0 ] 
		then
			data=$(cat user_review | grep ^"$user"":")
			sed -i "s/^"$data"/"$data"":Y"/g" user_review	
		else
			data=$(cat user_review | grep  ^"$user"":")
			sed -i "s/^"$data"/"$data"":N"/g" user_review	
		fi
	done
done
> user_review_print
header=$(sed 's/ /:/g' <<< "$(cat hosts_process|xargs)")
users=$(cat *_passwd | awk -F: '{print $1}' | sort -n | uniq)
echo "USERID:DESCRIPTION:$header" >> user_review_print

for user in $(echo $users)
do
	comment=$(cat *_passwd | grep -w $user":" | awk -F: '{print $5}'  | head -1)
	data1=$(cat user_review | grep -w $user":" | awk -F: '{print $1}')
	data2=$(cat user_review | grep -w $user":" | awk -F: '{for (i = 2; i <= NF ; ++i) {printf ("%s:", $i)}; printf("\n")}')
	echo "$data1":"$comment$data2" >> user_review_print
done
rm user_review 
mv user_review_print user_review.out

# Start procesing files to get admin users info
echo "Start processing files for admin privileges" 
> sudoers_review
header=$(sed 's/ /:/g' <<< "$(cat hosts_process|xargs)")
users=$(cat *_passwd | awk -F: '{print $1}' | sort -n | uniq)
echo "USERID:$header" >> sudoers_review
for user in $(echo $users)
do
	echo "$user":"" >> sudoers_review
done
for host in $(cat hosts_process)
do 
	echo "Processing host $host for user admin privileges ..."
	for user in $(echo $users)
	do
		exist=$(cat $host"_passwd" | grep -w $user":" | wc -l 2>/dev/null)
		if [ $exist -gt 0 ] 
		then
			ispriv=$(cat $host"_sudoers" | grep -w $user":" | wc -l 2>/dev/null)
			groups=$(cat $host"_group" | grep -w $user | awk -F: '{print $1}' | sort -n | uniq 2>/dev/null)
		for group in $(echo $groups)
		do 
			isprivg=$(cat $host"_sudoers" | grep -w $group | wc -l 2>/dev/null)
			count=$(expr 0 + $isprivg)
		done
			if [ $ispriv -gt 0 ] || [ $count -gt 0 ]  
			then
				data=$(cat sudoers_review | grep -w $user":" 2>/dev/null)
				sed -i "s/^"$data"/"$data"":Y"/g" sudoers_review	
			else
				data=$(cat sudoers_review | grep -w $user":" 2>/dev/null)
				sed -i "s/^"$data"/"$data"":N"/g" sudoers_review	
			fi
		else
			data=$(cat sudoers_review | grep -w $user":" 2>/dev/null)
			sed -i "s/^"$data"/"$data"":N"/g" sudoers_review	
		fi
	done
done
> sudoers_review_print
echo "USERID:DESCRIPTION:$header" >> sudoers_review_print

for user in $(echo $users)
do
	comment=$(cat *_passwd | grep -w $user":" | awk -F: '{print $5}'  | head -1 2>/dev/null)
	data1=$(cat sudoers_review | grep -w $user":" | awk -F: '{print $1}' 2>/dev/null)
	data2=$(cat sudoers_review | grep -w $user":" | awk -F: '{for (i = 2; i <= NF ; ++i) {printf ("%s:", $i)}; printf("\n")}' 2>/dev/null)
	comment2=$(echo $data2 | grep Y | wc -l 2>/dev/null)
	if [ $comment2 -gt 0 ];then 
		comment2=YES
	else
		comment2=NO
	fi
	echo "$data1":"$comment":"$comment2$data2" >> sudoers_review_print
done
rm sudoers_review
mv sudoers_review_print sudoers_review.out
rm hosts_process 

#Post processing files to remove OS Accounts 

for user in $(cat exclusions)
do
	getline=$(cat user_review.out | grep -n ^"$user"":" | awk -F: '{print $1}') 
	sed -i "${getline}d" user_review.out
	getline1=$(cat sudoers_review.out | grep -n ^"$user"":" | awk -F: '{print $1}') 
	sed -i "${getline1}d" sudoers_review.out
done
