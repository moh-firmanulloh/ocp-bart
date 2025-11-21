#!/bin/bash
#
#
obj_target="project"

if [[ "$#" -eq 6 ]];then
	project_name=$1
	ocp_source="${2%/}"
	ocp_user=$3
	ocp_pass=$4
	project_param=$5
	base_dir=$6
elif [[ $BUILDING_ARGS ]];then
	echo "$0 projectName ocpApiURL ocpUser ocpPass projectMigrate baseDir"
	exit 0
elif [[ -z "$config_file" ]];then
        echo "Finding migrate.conf"
        temp_work_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        temp_config_file="$temp_work_dir/../migrate.conf"
        if [[ -f $temp_config_file ]];then
                echo "migrate.conf found. Using configuration files as reference"
                config_file=$temp_config_file
        else
                unset $temp_config_file
                echo "No migrate.conf found"
        fi
fi
if [[ "$#" -ne 6 && -z "$config_file" ]];then
        echo "Define \$config_file or"
	echo "Usage: $0 projectName ocpApiURL ocpUser ocpPass projectMigrate baseDir"
	exit 1
fi

if [[ ! "$RUN_FROM_MAIN" ]];then
        echo "Finding pre-flight.sh"
        temp_pre_flight="$temp_work_dir/../pre-flight.sh"
        if [[ -f $temp_pre_flight ]];then
                pre_flight=$temp_pre_flight
                script_name=$(basename "${BASH_SOURCE[0]}")
                echo "pre-flight.sh found. Running pre-flight.sh script"
                bash $pre_flight $script_name $config_file
                if [[ $? -eq 0 ]];then
                        echo "All is well"
                        echo "Loading migrate.conf"
                        source $config_file
                else
                        echo "Pre-flight failed. Aborting."
                        exit 1
                fi
        else
                unset $temp_pre_flight
                echo "No pre-flight.sh found"
                exit 1
        fi
fi

kube_config="${base_dir}/.backup-kubeconfig"

echo "Source: $ocp_source"

function backup() {
	project_name=$1
	work_dir=$(echo $base_dir/backup/$project_name)
	echo "Backing up $obj_target $project_name"
	obj_res=$(oc --kubeconfig $kube_config get $obj_target $project_name)
	if [[ $? == 0 ]];then
		mkdir -p $(echo $work_dir)
		echo "Backing up $obj_target JSON"
		oc --kubeconfig $kube_config get $obj_target $project_name -ojson | jq -r 'del(.metadata.annotations."openshift.io/sa.scc.mcs",.metadata.annotations."openshift.io/sa.scc.supplemental-groups",.metadata.annotations."openshift.io/sa.scc.uid-range",.metadata.creationTimestamp,.metadata.labels."pod-security.kubernetes.io/audit",.metadata.labels."pod-security.kubernetes.io/audit-version",.metadata.labels."pod-security.kubernetes.io/warn",.metadata.labels."pod-security.kubernetes.io/warn-version",.metadata.resourceVersion, .metadata.uid, .spec, .status)' > $work_dir/$obj_target-$project_name.json
		echo "Result path: $work_dir/$obj_target-$project_name.json"
	else
		echo "$obj_target not found. Aborting.."
		exit 1
	fi
}
if [[ $project_param == "true" ]];then
        if [[ -f $kube_config ]];then
                current_ocp=$(oc --kubeconfig $kube_config whoami --show-server)
                current_user=$(oc --kubeconfig $kube_config whoami 2>/dev/null)
                if [[ ${current_ocp%/} != ${ocp_source%/} || $current_user == "" ]];then
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
	echo "Aborting.."
	exit 1
fi
