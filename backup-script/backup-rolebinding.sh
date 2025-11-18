#!/bin/bash
#
#
obj_target="rolebinding"
config_file="/home/thinkbook/ocp-bart/ocp-bart/migrate.conf"

if [[ "$#" -eq 6 ]];then
	project_name=$1
	ocp_source="${2%/}"
	ocp_user=$3
	ocp_pass=$4
	rolebinding_param=$5
	base_dir=$6
elif [[ $BUILDING_ARGS ]];then
	echo "$0 projectName ocpApiURL ocpUser ocpPass roleBindingMigrate baseDir"
	exit 0

	echo "Usage: $0 projectName ocpApiURL ocpUser ocpPass roleBindingMigrate baseDir"
	exit 1
fi

kube_config="${base_dir}/.backup-kubeconfig"

echo "Source: $ocp_source"

function backup() {
	project_name=$1
	work_dir=$(echo $base_dir/backup/$project_name/$obj_target)
	echo "Backing up $obj_target $project_name"
	readarray -t obj_res < <(oc --kubeconfig $kube_config get $obj_target -n $project_name --no-headers | egrep -v "system:deployers|system:image-builders|system:image-pullers" | awk '{print $1}')
	if [[ "${#obj_res[@]}" -ne 0 ]];then
		mkdir -p $(echo $work_dir)
		for resource in "${obj_res[@]}";do
			echo "Backing up $obj_target: $resource JSON"
			resource_file_name=$(echo $resource | tr ":" "_")
	       		oc --kubeconfig $kube_config get $obj_target $resource -n $project_name -ojson | jq -r 'del(.metadata.creationTimestamp,.metadata.resourceVersion, .metadata.uid, .status)' > $work_dir/$obj_target-$resource_file_name.json
			echo "Result path: $work_dir/$obj_target-$resource_file_name.json"
		done
	else
		echo "$obj_target not found. Skipping"
	fi
}

if [[ $rolebinding_param == "true" ]];then
        if [[ -f $kube_config ]];then
                current_ocp=$(oc --kubeconfig $kube_config whoami --show-server)
                current_user=$(oc --kubeconfig $kube_config whoami 2>/dev/null)
                if [[ ${current_ocp%/} != ${ocp_source%/} ]];then
                        oc login -u $ocp_user -p $ocp_pass $ocp_source --insecure-skip-tls-verify=true --kubeconfig $kube_config
                fi
        else
                        oc login -u $ocp_user -p $ocp_pass $ocp_source --insecure-skip-tls-verify=true --kubeconfig $kube_config
        fi

	if [[ ! -z $projects && -z $project_name ]];then
                for project_name in "${projects[@]}";do
                        backup $project_name
                done
        else
                backup $project_name
        fi
else
	echo "Skipping $obj_target"
fi
