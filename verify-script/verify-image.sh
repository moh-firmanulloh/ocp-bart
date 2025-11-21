#!/bin/bash
#
#
obj_list="deployment deploymentconfig daemonset statefulset cronjob"
GREEN='\033[0;32m'
NC='\033[0m'

if [[ "$#" -eq 9 ]];then
	project_name=$1
	ocp_source="${2%/}"
	ocp_source_user=$3
	ocp_source_pass=$4
	ocp_target="${5%/}"
	ocp_target_user=$6
	ocp_target_pass=$7
	image_param=$8
	base_dir=${9%/}
elif [[ $BUILDING_ARGS ]];then
	echo "$0 projectName ocpSourceApiURL ocpSourceUser ocpSourcePass ocpTargetApiURL ocpTargetUser ocpTargetPass imageMigrate baseDir"
        exit 0
elif [[ -z "$config_file" ]];then
        echo "Finding migrate.conf"
        temp_work_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        temp_config_file="$temp_work_dir/../migrate.conf"
        if [[ -f $temp_config_file ]];then
                echo "migrate.conf found. Using configuration files as reference"
                config_file=$temp_config_file
        else
                unset temp_config_file
                echo "No migrate.conf found"
        fi
fi
if [[ "$#" -ne 9 && -z "$config_file" ]];then
        echo "Define \$config_file or"
        echo "Usage: $0 projectName ocpSourceApiURL ocpSourceUser ocpSourcePass ocpTargetApiURL ocpTargetUser ocpTargetPass imageMigrate baseDir"
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
                unset temp_pre_flight
                echo "No pre-flight.sh found"
                exit 1
        fi
fi

work_dir=$(echo $base_dir/backup/$project_name/image)
kube_config_source="${base_dir}/.backup-kubeconfig"
kube_config_target="${base_dir}/.restore-kubeconfig"

if [[ -f $kube_config_source ]];then
        current_ocp=$(oc --kubeconfig $kube_config_source whoami --show-server)
        current_user=$(oc --kubeconfig $kube_config_source whoami 2>/dev/null)
        if [[ ${current_ocp%/} != ${ocp_source%/} || $current_user == "" ]];then
                oc login -u $ocp_source_user -p $ocp_source_pass $ocp_source --insecure-skip-tls-verify=true --kubeconfig $kube_config_source
        fi
else
                oc login -u $ocp_source_user -p $ocp_source_pass $ocp_source --insecure-skip-tls-verify=true --kubeconfig $kube_config_source
fi

if [[ -f $kube_config_target ]];then
        current_ocp=$(oc --kubeconfig $kube_config_target whoami --show-server)
        current_user=$(oc --kubeconfig $kube_config_target whoami 2>/dev/null)
        if [[ ${current_ocp%/} != ${ocp_target%/} || $current_user == "" ]];then
                oc login -u $ocp_target_user -p $ocp_target_pass $ocp_target --insecure-skip-tls-verify=true --kubeconfig $kube_config_target
        fi
else
                oc login -u $ocp_target_user -p $ocp_target_pass $ocp_target --insecure-skip-tls-verify=true --kubeconfig $kube_config_target
fi


echo "Source: $ocp_source"
echo "Target: $ocp_target"

function img_pattern_non_cj() {
	local container_name=$1
	local kb_config=$2
	oc --kubeconfig "$kb_config" get "$obj_target" "$resource" -n "$project_name" -ojson 2>/dev/null | jq -r --arg name "$container_name" '.spec.template.spec.containers[] | select(.name == $name) | .image'
}

function img_pattern_cj() {
	local container_name=$1
	local kb_config=$2
	oc --kubeconfig "$kb_config" get "$obj_target" "$resource" -n "$project_name" -ojson 2>/dev/null | jq -r --arg name "$container_name" '.spec.jobTemplate.spec.template.spec.containers[] | select(.name == $name) | .image'
}

function get_container_names() {
	local kb_config=$1
	if [[ $obj_target == "cronjob" ]]; then
	    oc --kubeconfig "$kb_config" get "$obj_target" "$resource" -n "$project_name" -ojson 2>/dev/null | jq -r '.spec.jobTemplate.spec.template.spec.containers[].name'
	else
	    oc --kubeconfig "$kb_config" get "$obj_target" "$resource" -n "$project_name" -ojson 2>/dev/null | jq -r '.spec.template.spec.containers[].name'
	fi
}

function verify() {
	project_name=$1
	echo "Checking Image on project $project_name"
        for obj_target in $(echo $obj_list);do
                readarray -t obj_res < <(oc --kubeconfig $kube_config_source get $obj_target -n $project_name --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null)
                if [[ "${#obj_res[@]}" -ne 0 ]];then
                        for resource in "${obj_res[@]}";do
				readarray -t container_names < <(get_container_names "$kube_config_source")
				for container_name in "${container_names[@]}"; do
					if [[ $obj_target == "cronjob" ]]; then
					    source_img_pattern=$(img_pattern_cj "$container_name" "$kube_config_source")
					    target_img_pattern=$(img_pattern_cj "$container_name" "$kube_config_target")
					else
					    source_img_pattern=$(img_pattern_non_cj "$container_name" "$kube_config_source")
					    target_img_pattern=$(img_pattern_non_cj "$container_name" "$kube_config_target")
					fi
					
					if [[ $source_img_pattern != "$target_img_pattern" ]]; then
					    echo -e "$obj_target: $resource ($container_name) ${RED}does not match${NC}"
					else
					    echo -e "$obj_target: $resource ($container_name) ${GREEN}match${NC}"
					fi
				done
			done
		else
			echo "$obj_target not found. Skipping"
		fi
        done
}

if [[ $image_param == "true" ]];then
	if [[ ! -z $projects ]];then
                for project_name in "${projects[@]}";do
                        verify $project_name
                done
        else
                verify $project_name
        fi
else
        echo "Skipping $obj_target"
fi
