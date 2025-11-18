#!/bin/bash
#
#
obj_target="clusterrolebinding"
config_file="/home/thinkbook/ocp-bart/ocp-bart/migrate.conf"

if [[ "$#" -eq 5 ]];then
	ocp_target=$1
	ocp_user=$2
	ocp_pass=$3
	clusterrolebinding_param=$4
	base_dir=$5
elif [[ $BUILDING_ARGS ]];then
	echo "$0 ocpApiURL ocpUser ocpPass clusterRoleBindingMigrate baseDir"
	exit 0
elif [[ ! -z "$config_file" && -f "$config_file" ]];then
        source "$config_file"
else
        echo "Define \$config_file or"
	echo "Usage: $0 ocpApiURL ocpUser ocpPass clusterRoleBindingMigrate baseDir"
	exit 1
fi

work_dir=$(echo $base_dir/backup/$obj_target)
kube_config="${base_dir}/.restore-kubeconfig"
migration_state="${base_dir}/.clusterrolebinding.state"
echo "Restore $obj_target"

function restore() {
	if [[ -d $work_dir ]];then
		migration_status=$(cat $migration_state)
		if [[ -f $migration_state && $migration_status == "DONE" ]];then
			echo "$obj_target already migrated. Skipiping."
		else
			echo "Target Cluster:" 
			oc --kubeconfig $kube_config whoami --show-server
			read -p "Proceed? (Y/n)" confirm
	
			if [[ $confirm != "Y" ]];then
	        		echo "Aborted."
			        exit 1
			fi
			for file in $(ls $work_dir);do	
				oc --kubeconfig $kube_config create -f $work_dir/$file
			done
		fi
	else
		echo "Skipping. No $obj_target."
	fi
	echo "DONE" > $base_dir/.clusterrolebinding.state
}

if [[ $clusterrolebinding_param == "true" ]];then
        if [[ -f $kube_config ]];then
                current_ocp=$(oc --kubeconfig $kube_config whoami --show-server)
                current_user=$(oc --kubeconfig $kube_config whoami 2>/dev/null)
                if [[ ${current_ocp%/} != ${ocp_target%/} || $current_user == "" ]];then
                        oc login -u $ocp_user -p $ocp_pass $ocp_target --insecure-skip-tls-verify=true --kubeconfig $kube_config
                fi
        else
                        oc login -u $ocp_user -p $ocp_pass $ocp_target --insecure-skip-tls-verify=true --kubeconfig $kube_config
        fi
	restore
else
	echo "Aborted due to migrate_param $migrate_param"
fi
