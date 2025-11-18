#!/bin/bash
#
#
obj_target="clusterrolebinding"

if [[ "$#" -eq 5 ]];then
	ocp_source=$1
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

echo "Backing up $obj_target"
echo "Source: $ocp_source"

work_dir=$(echo $base_dir/backup/$obj_target)
kube_config="$base_dir/.backup-kubeconfig"

if [[ $clusterrolebinding_param == "true" ]];then
	if [[ -f $kube_config ]];then
                current_ocp=$(oc --kubeconfig $kube_config whoami --show-server)
                current_user=$(oc --kubeconfig $kube_config whoami 2>/dev/null)
                if [[ ${current_ocp%/} != ${ocp_source%/} || $current_user == "" ]];then
			oc login -u $ocp_user -p $ocp_pass $ocp_source --insecure-skip-tls-verify=true --kubeconfig $kube_config
		fi
	else
			oc login -u $ocp_user -p $ocp_pass $ocp_source --insecure-skip-tls-verify=true --kubeconfig $kube_config
	fi
	readarray -t obj_res < <(oc --kubeconfig $kube_config get $obj_target -ojson | jq -r '.items[] | select((.subjects | type == "array") and any(.subjects[]?; (type == "object") and ((.kind == "User" or .kind == "Group") and (.name | test("system:*|kube-*") | not)))) | .metadata.name')
	if [[ "${#obj_res[@]}" -ne 0 ]];then
		mkdir -p $(echo $work_dir)
		for resource in "${obj_res[@]}";do
			echo "Backing up $obj_target: $resource JSON"
			resource_file_name=$(echo $resource | tr ":" "_")
	       		oc --kubeconfig $kube_config get $obj_target $resource -ojson | jq -r 'del(.metadata.creationTimestamp,.metadata.resourceVersion, .metadata.uid, .status)' > $work_dir/$obj_target-$resource_file_name.json
			echo "Result path: $work_dir/$obj_target-$resource_file_name.json"
		done
	else
		echo "$obj_target not found. Skipping"
	fi
else
	echo "Skipping $obj_target"
fi
