#!/bin/bash
#
#
obj_target="deployment"

if [[ "$#" -eq 6 ]];then
	project_name=$1
	ocp_target="${2%/}"
	ocp_user=$3
	ocp_pass=$4
	deployment_param=$5
	base_dir=$6
elif [[ $BUILDING_ARGS ]];then
	echo "$0 projectName ocpApiURL ocpUser ocpPass deploymentMigrate baseDir"
	exit 0
elif [[ ! -z "$config_file" && -f "$config_file" ]];then
        source "$config_file"
else
        echo "Define \$config_file or"
	echo "Usage: $0 projectName ocpApiURL ocpUser ocpPass deploymentMigrate baseDir"
	exit 1
fi

kube_config="${base_dir}/.restore-kubeconfig"

function restore() {
	project_name=$1
	work_dir=$(echo $base_dir/backup/$project_name/$obj_target)
	echo "Restore $obj_target $project_name"
	if [[ -d $work_dir ]];then
		echo "Target Cluster:" 
		oc --kubeconfig $kube_config whoami --show-server
		read -p "Proceed? (Y/n)" confirm

		if [[ $confirm != "Y" ]];then
        		echo "Aborted."
		        exit 1
		fi
		for file in $(ls $work_dir);do	
			oc --kubeconfig $kube_config create -f $work_dir/$file
			dep_name=$(echo $file | cut -d"." -f1 | cut -d"-" -f2-)
			for repset in $(ls $base_dir/backup/$project_name/replicaset/replicaset-$dep_name*);do
				oc --kubeconfig $kube_config apply -f $repset
				sleep 5;
			done
		done
	else
		echo "Skipping. No $obj_target"
	fi
}

if [[ $deployment_param == "true" ]];then
	if [[ -f $kube_config ]];then
                current_ocp=$(oc --kubeconfig $kube_config whoami --show-server)
                current_user=$(oc --kubeconfig $kube_config whoami 2>/dev/null)
                if [[ ${current_ocp%/} != ${ocp_target%/} || $current_user == "" ]];then
                        oc login -u $ocp_user -p $ocp_pass $ocp_target --insecure-skip-tls-verify=true --kubeconfig $kube_config
                fi
        else
                        oc login -u $ocp_user -p $ocp_pass $ocp_target --insecure-skip-tls-verify=true --kubeconfig $kube_config
        fi

	if [[ ! -z $projects && -z $project_name ]];then
                for project_name in "${projects[@]}";do
                        restore $project_name
                done
        else
                restore $project_name
        fi
else
	echo "Aborted due to migrate_param $migrate_param"
fi
